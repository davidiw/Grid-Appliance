# Block SSH over IPOP
iptables -D INPUT -p tcp -i tap0 --sport 22 -j DROP 
iptables -D OUTPUT -p tcp -o tap0 --dport 22 -j DROP 
iptables -D INPUT -p tcp -i tap0 --dport 22 -j DROP
iptables -D OUTPUT -p tcp -o tap0 --sport 22 -j DROP

/usr/sbin/sshd
