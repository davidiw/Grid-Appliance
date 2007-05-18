/*
 * NAT Check - test NATs and firewalls for P2P-friendliness.
 * Copyright 2004 Bryan Ford
 * You may freely use and distribute this program
 * according to the terms of the GNU General Public License.
 *
 * Credits:
 *	Windows port by Philippe Verdy
 *	MAC OS X port by Richard Elmore
 *
 * Version 3: added testing for TCP-based P2P connection support
 * Version 2: added test for loopback translation support
 * Version 1: first public release, UDP-only
 *
 * Known to compile under Linux, FreeBSD, and Windows/MinGW with -lws2_32.
 * Your mileage may vary.  No warranty, blah blah blah.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <errno.h>
#include <assert.h>
#include <inttypes.h>
#include <sys/types.h>

#ifdef __APPLE__
#define _BSD_SOCKLEN_T_
#endif

#ifdef WIN32

#include <winsock.h>
#define socklen_t int

#else /* not WIN32 */

#include <unistd.h>
#include <netdb.h>
#include <sys/socket.h>
#include <sys/select.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#endif /* not WIN32 */

#ifndef max
#define max(a,b) ((a) > (b) ? (a) : (b))
#endif

#define HOST_NAME_MAX	256

#define NTRIES		20

#define SERV1		"planet1.seattle.intel-research.net"
#define SERV2		"planet3.pittsburg.intel-research.net"
#define SERV3		"pl1.cs.utk.edu"

#define SERVPORT 	61235	

#define REQMAGIC	0x76849268
#define REPLMAGIC	0x01967293
#define LOOPMAGIC	0x86836173

struct request {
	uint32_t magic;
};

struct reply {
	uint32_t magic;
	struct in_addr pubaddr;
	uint16_t pubport;
};

int verbose = 0;


struct sockaddr_in tsin, usin, sin1, sin2, sin3;
int tcp0, tcp1, tcp2, tcp3, tcp4, udp1, udp2, incb, inloop, maxsock;
fd_set rfds, wfds;
struct sockaddr_in myt1, myt2, myt3, myu1, myu2, myu3;
int tcploop = 0, udploop = 0, t3toosoon = 0;


int die(int level) {
#ifdef WIN32
	WSACleanup();
#endif
	if (level)
		exit(level);
	return level;
}


#ifdef WIN32
void perr(const char *msg)
{
	LPVOID lpMsgBuf;
	int e;

	lpMsgBuf = (LPVOID)"Unknown error";
	e = WSAGetLastError();
	if (FormatMessage(
			FORMAT_MESSAGE_ALLOCATE_BUFFER |
			FORMAT_MESSAGE_FROM_SYSTEM |
			FORMAT_MESSAGE_IGNORE_INSERTS,
			NULL, e,
			MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
				// Default language
			(LPTSTR)&lpMsgBuf, 0, NULL)) {
		fprintf(stderr, "%s: error %d: %s\n", msg, e, lpMsgBuf);
		LocalFree(lpMsgBuf);
	} else
		fprintf(stderr, "%s: error %d\n", msg, e);
}

/* Check for an error code indicating that a read or write would block */
int eblock()
{
	int e = WSAGetLastError();
	if (e == WSAEWOULDBLOCK)
		return 1;
	return 0;
}

/* Check for an error code indicating that a connect() is still in progress */
int econnblock()
{
	int e = WSAGetLastError();
	if (e == WSAEINPROGRESS || e == WSAEALREADY ||
	    e == WSAEWOULDBLOCK || e == WSAEINVAL)
		return 1;
	return 0;
}

/* Check for an error code indicating that a connect() is complete */
int econndone()
{
	int e = WSAGetLastError();
	if (e == WSAEISCONN)
		return 1;
	return 0;
}

#else /* not WIN32 */

#define perr(msg) perror(msg)

#define eblock() (errno == EAGAIN || errno == EWOULDBLOCK)
#define econnblock() (errno == EINPROGRESS || errno == EALREADY)
#define econndone() (errno == EISCONN)

#endif


void perrdie(const char *msg) {
	perr(msg);
	die(1);
}

void getaddr(const char *hostname, struct in_addr *addr)
{
	struct hostent *h;

	h = gethostbyname(hostname);
	if (h == 0)
		perrdie(hostname);
	if (h->h_addrtype != AF_INET) {
		fprintf(stderr, "%s: unexpected address type %d\n",
				hostname, h->h_addrtype);
	}
	*addr = *(struct in_addr*)(h->h_addr);
}

void lookup(int n, const char *hostname, struct sockaddr_in *sin)
{
	getaddr(hostname, &sin->sin_addr);

	sin->sin_family = AF_INET;
	sin->sin_port = htons(SERVPORT);

	if (verbose)
		fprintf(stderr, "server %d: %s at %s:%d\n",
				n, hostname, inet_ntoa(sin->sin_addr),
				ntohs(sin->sin_port));
}

int mksock(int type)
{
	int sock = socket(AF_INET, type, 0);
	if (sock < 0)
		perrdie("socket");
	return sock;
}

void setnonblock(int sock)
{
#ifdef WIN32
	unsigned long fl = 1;
	if (ioctlsocket(sock, FIONBIO, &fl) < 0)
		perrdie("socketioctl");
#else
	int fl = fcntl(sock, F_GETFL);
	if (fl < 0)
		perrdie("fcntl");
	if (fcntl(sock, F_SETFL, fl | O_NONBLOCK) < 0)
		perrdie("fcntl");
#endif
}

void setreuse(int sock)
{
	const int one = 1;

#ifdef SO_REUSEADDR
	if (setsockopt(sock, SOL_SOCKET, SO_REUSEADDR,
			(const void*)&one, sizeof(one)) < 0)
		perrdie("setsockopt(SO_REUSEADDR)");
#endif
#ifdef SO_REUSEPORT
	if (setsockopt(sock, SOL_SOCKET, SO_REUSEPORT,
			(const void*)&one, sizeof(one)) < 0)
		perrdie("setsockopt(SO_REUSEPORT)");
#endif
}

void listentcp()
{
	struct sockaddr_in sin;
	socklen_t sinlen;
	int rc;

	while (1) {
		sinlen = sizeof(sin);
		rc = accept(tcp0, (struct sockaddr*)&sin, &sinlen);
		if (rc < 0) {
			if (eblock())
				return;
			perrdie("accept");
		}

		/* Got a new incoming connection.  Make it nonblocking. */
		setnonblock(rc);

		if (verbose)
			fprintf(stderr, "Connection from %s:%d\n",
				inet_ntoa(sin.sin_addr),
				ntohs(sin.sin_port));

		/* Figure out what to do with it. */
		if (sin.sin_addr.s_addr == sin3.sin_addr.s_addr
		    && sin.sin_port == sin3.sin_port) {
			if (incb < 0) {
				incb = rc;
				FD_SET(incb, &rfds);
				maxsock = max(maxsock, incb);
			} else
				close(rc);
		} else {
			if (inloop < 0) {
				inloop = rc;
				FD_SET(inloop, &rfds);
				maxsock = max(maxsock, inloop);
			} else
				close(rc);
		}
	}
}

void checktcp(int servn, int *sock, const struct sockaddr_in *connsin,
		struct sockaddr_in *mysin)
{
	struct request rq;
	struct reply rp;
	int rc;

	if (*sock < 0)
		return;

	/* See if we're waiting for a connect attempt to complete. */
	if (FD_ISSET(*sock, &wfds)) {

		/* Retry the connection attempt. */
		rc = connect(*sock, (const struct sockaddr*)connsin,
				sizeof(*connsin));
		if (rc < 0 && econnblock())
			return;	/* still not done */
		if (rc < 0 && !econndone())
			perrdie("checktcp connect");

		/* Try to send() our request into the TCP socket,
		   until we either succeed or fail with a "hard error."
		   In the former case, move this socket from wfds to rfds
		   in order to wait for the server's reply. */
		rq.magic = htonl(REQMAGIC);
		rc = send(*sock, (const char*)&rq, sizeof(rq), 0);
		if (rc < 0) {
			if (eblock())
				return;
			perrdie("tcp send");
		}

		if (verbose)
			fprintf(stderr, "Connection to server %d complete\n",
				servn);

		FD_CLR(*sock, &wfds);
		FD_SET(*sock, &rfds);
		return;
	}

	if (!FD_ISSET(*sock, &rfds))
		return;

	/* Now see if there's any data available on the socket. */
	rc = recv(*sock, (char*)&rp, sizeof(rp), 0);
	if (rc < 0) {
		if (eblock())
			return;
		perrdie("tcp recv");
	}
	if (rc < sizeof(rp)) {
		if (verbose)
			fprintf(stderr,
				"received runt TCP response from server %d\n",
				servn);
		goto closeit;
	}

	if (rp.magic != htonl(REPLMAGIC)) {
		if (verbose)
			fprintf(stderr,
				"received TCP reply with bad magic value\n");
		goto closeit;
	}
	if (mysin->sin_addr.s_addr != INADDR_ANY) {
		if (verbose)
			fprintf(stderr,
				"received multiple TCP responses!?\n");
		goto closeit;
	}

	if (verbose)
		fprintf(stderr, "Server %d reports my TCP address as %s:%d\n",
				servn, inet_ntoa(rp.pubaddr),
				ntohs(rp.pubport));

	mysin->sin_addr = rp.pubaddr;
	mysin->sin_port = rp.pubport;

	/* When server 2 responds: */
	if (servn == 2) {

		/* Make a TCP connection attempt to server 3.
		   Since server 2 has just responded,
		   this should mean that server 3 has already
		   initiated a connection attempt inward through the NAT.
		   While the server 1 and 2 connections are client/server,
		   the server 3 connection is a simultaneous TCP open
		   initiated in active mode by both ourselves and server 3.
		   If our NAT is rejecting incoming connections with RSTs,
		   then server 3's incoming connection attempt will fail
		   before our outgoing one can meet it.
		   We want to detect that situation.
		   If our NAT isn't blocking incoming connections at all,
		   then we'll have already received and accept()ed
		   server 3's incoming connection attempt,
		   causing this attempt to fail with EADDRINUSE. */
		rc = connect(tcp3, (const struct sockaddr*)&sin3,
				sizeof(sin3));
#ifdef EADDRINUSE
		if (rc < 0 && errno == EADDRINUSE) {
			if (verbose)
				fprintf(stderr,
					"Connection already accepted "
					"from server 3\n");
		} else
#endif
		if (rc < 0 && !econnblock()) {
			if (verbose)
				perr("TCP simultaneous open "
					"with server 3 failed");
		} else {
			if (verbose)
				fprintf(stderr,
					"Initiated TCP server 3 connection\n");
			FD_SET(tcp3, &wfds);
			maxsock = max(maxsock, tcp3);
		}

		/* Also initiate a "loopback" TCP connection
		   to our own public (NATted) address as seen by server 2,
		   in order to test for loopback translation support. */
		rc = connect(tcp4, (const struct sockaddr*)&myt2,
				sizeof(myt2));
		if (rc < 0 && !econnblock())
			perrdie("connect tcp4");
		if (verbose)
			fprintf(stderr,
				"Initiated TCP loopback connection\n");
		FD_SET(tcp4, &wfds);
		maxsock = max(maxsock, tcp4);
	}

closeit:
	/* Remove this socket from the set of fds we are watching.
	   LEAVE IT OPEN until we exit, however,
	   to keep the NAT from closing the hole yet. */
	FD_CLR(*sock, &rfds);
	*sock = -1;
	return;
}

int checkudp(int servn, struct reply *rp, struct sockaddr_in *sin,
		struct sockaddr_in *servsin, struct sockaddr_in *mysin)
{
	if (sin->sin_addr.s_addr != servsin->sin_addr.s_addr ||
			sin->sin_port != servsin->sin_port)
		return 0;

	if (verbose)
		fprintf(stderr, "Server %d reports my UDP address as %s:%d\n",
				servn, inet_ntoa(rp->pubaddr),
				ntohs(rp->pubport));

	if (mysin->sin_addr.s_addr != INADDR_ANY) {
		/* We already received a response from this server */

		if (mysin->sin_addr.s_addr != rp->pubaddr.s_addr ||
				mysin->sin_port != rp->pubport) {
			fprintf(stderr, "Server %d reports my address "
					"INCONSISTENTLY as %s:%d and %s:%d\n",
					servn,
					inet_ntoa(mysin->sin_addr),
					ntohs(mysin->sin_port),
					inet_ntoa(rp->pubaddr),
					ntohs(rp->pubport));
		}

		return 1;
	}

	/* record the address reported by the server */
	mysin->sin_family = AF_INET;
	mysin->sin_addr = rp->pubaddr;
	mysin->sin_port = rp->pubport;

	return 1;
}

void recvudp()
{
	struct sockaddr_in sin;
	socklen_t sinlen;
	struct request rq;
	struct reply rp;
	int rc;

	for (;;) {
		sinlen = sizeof(sin);
		rc = recvfrom(udp1, (char*)&rp, sizeof(rp), 0,
				(struct sockaddr*)&sin, &sinlen);
		if (rc < 0 && eblock())
			break;

		if (rc == sizeof(rq) &&
			rp.magic == htonl(LOOPMAGIC)) {
			if (verbose)
				fprintf(stderr,
					"Loopback packet from %s port %d\n",
					inet_ntoa(sin.sin_addr),
					ntohs(sin.sin_port));
			udploop = 1;
			continue;
		}

		if (rc < sizeof(rp)) {
			if (verbose)
				fprintf(stderr,
					"Received runt packet\n");
			continue;
		}
		if (rp.magic != htonl(REPLMAGIC)) {
			if (verbose)
				fprintf(stderr,
					"Reply with bad magic value\n");
			continue;
		}

		/* Check the source of the datagram */
		if (!checkudp(1, &rp, &sin, &sin1, &myu1) &&
			!checkudp(2, &rp, &sin, &sin2, &myu2) &&
			!checkudp(3, &rp, &sin, &sin3, &myu3)) {
			if (verbose)
				fprintf(stderr,
					"Stray packet from %s\n",
					inet_ntoa(sin.sin_addr));
			continue;
		}
	}
}

void checkloopback()
{
	struct request rq;
	int rc;

	/* See if our outgoing loopback connection attempt needs attention. */
	if (tcp4 >= 0 && FD_ISSET(tcp4, &wfds)) {

		/* Retry the connection attempt. */
		rc = connect(tcp4, (const struct sockaddr*)&myt2, sizeof(myt2));
		if (rc < 0 && econnblock())
			goto notdone;	/* still not done */
		if (rc < 0 && !econndone())
			perrdie("checkloopback connect");

		/* Send the loopback request message */
		rq.magic = htonl(LOOPMAGIC);
		rc = send(tcp4, (const char*)&rq, sizeof(rq), 0);
		if (rc < 0 && eblock()) {
			goto notdone; /* not yet - just try again later */
		} else {
			/* success or hard failure -
			   either way, we're done with this socket. */
			FD_CLR(tcp4, &wfds);
			close(tcp4);
			tcp4 = -1;
		}
	}
	notdone:

	/* Check the incoming TCP loopback connection */
	if (inloop >= 0 &&
	    (rc = recv(inloop, (void*)&rq,
			sizeof(rq), 0)) >= 0) {
		if (verbose)
			fprintf(stderr, "Loopback received\n");
		if (rc == sizeof(rq) && 
		    rq.magic == htonl(LOOPMAGIC)) {
			tcploop = 1;
		}
		FD_CLR(inloop, &rfds);
		close(inloop);
		inloop = -1;
	}
}

int main(int argc, char **argv)
{
	struct sockaddr_in sin;
	socklen_t sinlen;
	struct request rq;
	int i, rc;
#ifdef WIN32
	WSADATA wsaData;

	if (WSAStartup(MAKEWORD(2, 2), &wsaData) != 0)
		perrdie("Windows sockets 2.2 startup");
	if (verbose) {
		fprintf(stderr, "Using %s (Status: %s)\n",
			wsaData.szDescription, wsaData.szSystemStatus);
		fprintf(stderr, "with API versions %d.%d to %d.%d\n\n",
			LOBYTE(wsaData.wVersion), HIBYTE(wsaData.wVersion),
			LOBYTE(wsaData.wHighVersion), HIBYTE(wsaData.wHighVersion));
	}
#endif

	/* Dummy uses, for unused parameters */
	for (i = 1; i < argc; i++) {
		if (strcmp(argv[i], "-v") == 0)
			verbose = 1;
		else {
			fprintf(stderr, "Usage: natcheck [-v]\n"
					"Options:\n"
					" -v     verbose\n");
			exit(1);
		}
	}

	/* Lookup the three well-known servers */
	lookup(1, SERV1, &sin1);
	lookup(2, SERV2, &sin2);
	lookup(3, SERV3, &sin3);

	/* Make a TCP socket and bind it to an OS-selected port */
	tcp0 = mksock(SOCK_STREAM);
	sin.sin_family = AF_INET;
	sin.sin_addr.s_addr = INADDR_ANY;
	sin.sin_port = 0;
	if (bind(tcp0, (struct sockaddr*)&sin, sizeof(sin)) < 0)
		perrdie("bind tcp0");

	/* Find the TCP socket name actually bound (tsin) */
	sinlen = sizeof(tsin);
	if (getsockname(tcp0, (struct sockaddr*)&tsin, &sinlen) < 0)
		perrdie("getsockname tcp0");
	assert(tsin.sin_port != 0);
	if (verbose)
		fprintf(stderr, "Local TCP port: %d\n", ntohs(tsin.sin_port));

	/* Make a UDP socket and bind it to an OS-selected port.
	   Make sure the TCP and UDP ports are different
	   because some NATs bind the TCP and UDP port namespaces,
	   which could make the tests interfere with each other. */
	do {
		udp1 = mksock(SOCK_DGRAM);
		if (bind(udp1, (struct sockaddr*)&sin, sizeof(sin)) < 0)
			perrdie("bind udp1");

		/* Find the TCP socket name actually bound (tsin) */
		sinlen = sizeof(usin);
		if (getsockname(udp1, (struct sockaddr*)&usin, &sinlen) < 0)
			perrdie("getsockname udp1");
		assert(usin.sin_port != 0);

	} while (usin.sin_port == tsin.sin_port);
	if (verbose)
		fprintf(stderr, "Local UDP port: %d\n", ntohs(usin.sin_port));

	/* Make me bunch more TCP and UDP sockets */
	tcp1 = mksock(SOCK_STREAM);
	tcp2 = mksock(SOCK_STREAM);
	tcp3 = mksock(SOCK_STREAM);
	tcp4 = mksock(SOCK_STREAM);
	udp2 = mksock(SOCK_DGRAM);

	/* Enable address and port reuse on the TCP sockets
	   that we will have to bind to the same port. */
	setreuse(tcp0);
	setreuse(tcp1);
	setreuse(tcp2);
	setreuse(tcp3);

	/* Place all of our sockets in nonblocking mode */
	setnonblock(tcp0);
	setnonblock(tcp1);
	setnonblock(tcp2);
	setnonblock(tcp3);
	setnonblock(tcp4);
	setnonblock(udp1);
	setnonblock(udp2);

	/* Bind TCP sockets 1, 2, and 3 to the same name as tcp0. */
	if (bind(tcp1, (struct sockaddr*)&tsin, sizeof(tsin)) < 0)
		perrdie("bind tcp1 - port reuse not supported?");
	if (bind(tcp2, (struct sockaddr*)&tsin, sizeof(tsin)) < 0)
		perrdie("bind tcp2");
	if (bind(tcp3, (struct sockaddr*)&tsin, sizeof(tsin)) < 0)
		perrdie("bind tcp3");

	/* TCP socket 0 is our listen socket for incoming TCP connections. */
	if (listen(tcp0, 0) < 0)
		perrdie("listen");

	/* Bind the secondary UDP socket to any port number */
	sin.sin_family = AF_INET;
	sin.sin_addr.s_addr = INADDR_ANY;
	sin.sin_port = 0;
	if (bind(udp2, (struct sockaddr*)&sin, sizeof(sin)) < 0)
		perrdie("bind");

	/* Clear the variables in which we collect
	 * our various NATted public addresses
	 * as we discover them. */
	sin.sin_family = AF_INET;
	sin.sin_addr.s_addr = INADDR_ANY;
	sin.sin_port = 0;
	myt1 = sin;
	myt2 = sin;
	myt3 = sin;
	myu1 = sin;
	myu2 = sin;
	myu3 = sin;

	/* Set up our fdsets for select */
	maxsock = 0;
	FD_ZERO(&rfds); FD_ZERO(&wfds);
	FD_SET(tcp0, &rfds); maxsock = max(maxsock, tcp0);
	FD_SET(udp1, &rfds); maxsock = max(maxsock, udp1);

	/* If our OS eagerly accepts server 3's incoming callback
	   via our listen socket (as Linux typically does for examlpe),
	   instead of connecting it to our outgoing tcp3 socket (as BSD does),
	   then the accepted incoming socket will be saved in incb.
	   Any other incoming callback we assume to be our own loopback,
	   and is saved as inloop. */
	incb = inloop = -1;

	/* Attempt nonblocking TCP connections to server 1 and 2. */
	rc = connect(tcp1, (const struct sockaddr*)&sin1, sizeof(sin1));
	if (rc < 0 && !econnblock())
		perrdie("connect tcp1");
	FD_SET(tcp1, &wfds); maxsock = max(maxsock, tcp1);
	rc = connect(tcp2, (const struct sockaddr*)&sin2, sizeof(sin2));
	if (rc < 0 && !econnblock())
		perrdie("connect tcp2");
	FD_SET(tcp2, &wfds); maxsock = max(maxsock, tcp2);

	/* Ping the servers 10 times */
	for (i = 1; i <= NTRIES; i++) {

		int timeout;

		fprintf(stderr, "Request %d of %d...\n", i, NTRIES);

		/* Send ping datagrams from our primary UDP socket
		   to servers 1 and 2. */
		rq.magic = htonl(REQMAGIC);
		if (sendto(udp1, (const char*)&rq, sizeof(rq), 0,
				(struct sockaddr*)&sin1, sizeof(sin1)) < 0)
			perrdie("sendto");
		if (sendto(udp1, (const char*)&rq, sizeof(rq), 0,
				(struct sockaddr*)&sin2, sizeof(sin2)) < 0)
			perrdie("sendto");

		/* If we know our primary UDP socket's public address
		   as seen by server 2 yet,
		   then also send a ping datagram to that public address
		   in order to test for loopback translation support. */
		rq.magic = htonl(LOOPMAGIC);
		if (myu2.sin_addr.s_addr != INADDR_ANY &&
		    sendto(udp2, (const char*)&rq, sizeof(rq), 0,
				(struct sockaddr*)&myu2, sizeof(myu2)) < 0)
			perrdie("sendto");

		timeout = 0;
		while (!timeout) {
			struct timeval tv;
			fd_set trfds, twfds;

			tv.tv_sec = 1;	/* wait 1 sec between retries */
			tv.tv_usec = 0;
			trfds = rfds;
			twfds = wfds;
			rc = select(maxsock+1, &trfds, &twfds, 0, &tv);
			if (rc < 0)
				perrdie("select");
			if (rc == 0) /* timeout */
				timeout = 1;

			/* Accept any new incoming TCP connection */
			listentcp();

			/* Check for available TCP responses */
			checktcp(1, &tcp1, &sin1, &myt1);
			checktcp(2, &tcp2, &sin2, &myt2);
			checktcp(3, &tcp3, &sin3, &myt3);
			checktcp(3, &incb, NULL, &myt3);

			/* If we get a callback from server 3
			   before we get a response from server 2,
			   it means our firewall isn't filtering
			   incoming connections as aggressively as it could. */
			if (myt3.sin_port != 0 && myt2.sin_port == 0)
				t3toosoon = 1;

			/* Handle TCP loopback stuff */
			checkloopback();

			/* Receive all available incoming UDP datagrams */
			recvudp();
		}
	}

	if (myt1.sin_addr.s_addr == INADDR_ANY) {
		fprintf(stderr, "Could not contact TCP server 1 (%s at %s)\n", 
				SERV1, inet_ntoa(sin1.sin_addr));
		die(1);
	}
	if (myt2.sin_addr.s_addr == INADDR_ANY) {
		fprintf(stderr, "Could not contact TCP server 2 (%s at %s)\n", 
				SERV2, inet_ntoa(sin2.sin_addr));
		die(1);
	}

	if (myu1.sin_addr.s_addr == INADDR_ANY) {
		fprintf(stderr, "Could not contact UDP server 1 (%s at %s)\n", 
				SERV1, inet_ntoa(sin1.sin_addr));
		die(1);
	}
	if (myu2.sin_addr.s_addr == INADDR_ANY) {
		fprintf(stderr, "Could not contact UDP server 2 (%s at %s)\n", 
				SERV2, inet_ntoa(sin2.sin_addr));
		die(1);
	}

	printf("\nTCP RESULTS:\n");

	/* Check for public address/port number consistency */
	if (myt1.sin_addr.s_addr == myt2.sin_addr.s_addr &&
			myt1.sin_port == myt2.sin_port) {
		printf("TCP consistent translation:           YES "
				"(GOOD for peer-to-peer)\n");
	} else {
		printf("TCP consistent translation:           NO  "
				"(BAD for peer-to-peer)\n");
	}

	/* See if our simultaneous open with server 3 succeeded */
	if (myt3.sin_port != 0) {
		printf("TCP simultaneous open:                YES "
				"(GOOD for peer-to-peer)\n");
	} else {
		printf("TCP simultaneous open:                NO  "
				"(BAD for peer-to-peer)\n");
	}

	/* See if loopback messages got through */
	if (tcploop) {
		printf("TCP loopback translation:             YES "
				"(GOOD for peer-to-peer)\n");
	} else {
		printf("TCP loopback translation:             NO  "
				"(BAD for P2P over Twice-NAT)\n");
	}

	/* See if messages from SERV3 ("attacker") got through */
	if (t3toosoon) {
		printf("TCP unsolicited connections filtered: NO  "
				"(BAD for security)\n");
	} else {
		printf("TCP unsolicited connections filtered: YES "
				"(GOOD for security)\n");
	}

	printf("\nUDP RESULTS:\n");

	/* Check for public address/port number consistency */
	if (myu1.sin_addr.s_addr == myu2.sin_addr.s_addr &&
			myu1.sin_port == myu2.sin_port) {
		printf("UDP consistent translation:           YES "
				"(GOOD for peer-to-peer)\n");
	} else {
		printf("UDP consistent translation:           NO  "
				"(BAD for peer-to-peer)\n");
	}

	/* See if loopback messages got through */
	if (udploop) {
		printf("UDP loopback translation:             YES "
				"(GOOD for peer-to-peer)\n");
	} else {
		printf("UDP loopback translation:             NO  "
				"(BAD for P2P over Twice-NAT)\n");
	}

	/* See if messages from SERV3 ("attacker") got through */
	if (myu3.sin_addr.s_addr != INADDR_ANY) {
		printf("UDP unsolicited messages filtered:    NO  "
				"(BAD for security)\n");
	} else {
		printf("UDP unsolicited messages filtered:    YES "
				"(GOOD for security)\n");
	}

	return die(0);
}
