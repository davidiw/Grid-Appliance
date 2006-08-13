********************************************************************************
* (C) Advanced Computing and Information Systems Lab
*     Dept. of Electrical & Computer Engineering
*     University of Florida
*     P.O. Box 116200, 
*     339 Larsen Hall,
*     Gainesville, FL 32611-6200
*     USA
*
*
*    Team: Abhishek Agrawal, Arijit Ganguly, David Wolinsky,
*    P. Oscar Boykin, Renato Figueiredo 
*
*    For more information about this and other related projects:
*    http://wow.acis.ufl.edu 
*
********************************************************************************

INTRODUCTION
------------

This VM appliance allows users to connect to an ad-hoc pool of appliances which 
run a Grid computing scheduler (Condor) to execute high-throughput, 
long-running jobs. Appliances are connected to each other through a virtual 
network, using private IP addresses. Once your appliance boots up, it
connects to a Condor pool automatically, and you are able to submit
jobs to machines that are aprt of this pool right away.

For you to make use of this appliance, it's important to understand how
to submit jobs using Condor.  Documents describing the design and 
configuration of the appliance and the Condor Manual are packaged
alongside the  VM image of the appliance.
More information about the appliance and other related projects, including 
links to the latest VM image and detailed documentation can be found at:

http://wow.acis.ufl.edu

Users are advised to visit this page for most up-to-date information and 
available updates.

This appliance uses VMware virtualization software. The following products
have been tested: Workstation 5.5, Player 1.0.1, Server 1.0.0. 

If you already have VMware in your system, please skip to the next section.
If you obtained the appliance via a CD or DVD, a copy of the free VMware Player
software package is included.

INSTALLING VMWARE PLAYER
------------------------
"VMware Player - Run any virtual machine on a Windows or Linux PC"

VMware Player installation files for Windows and Linux (rpm and tar) are
provided. Alternatively, VMware Player can be downloaded from:
http://www.vmware.com/download

To install the VMware Player on your machine:

1) Read the End User License Agreement document shipped with your CD/DVD
(also available for download from the Grid appliance web site).

2) Windows hosts: Execute the VMware-player installation program and follow
   the appropriate installation steps 
   Linux hosts: Two forms of distribution aree provided: an RPM package,
   and a "tar" file. If you use the RPM distribution, use rpm -i to
   install VMplayer and vmware-config.pl to configure your installation.
   If you use the tar distribution, untar it, then locate and execute the 
   vmware-install.pl and vmware-config.pl scripts to finish the installation.

BOOTING UP THE APPLIANCE
------------------------

To boot up the Grid Appliance:

Step 1: Copy and unzip the file grid_appliance.zip to your hard disk.
Step 2: Open and power on the Grid-Appliance with the above installed VMware
        product by double-clicking the VMware configuration file
Step 3: Start the virtual Machine (VM)
Step 4: Log in as user condor 
        The initial password is: password 
        You will be prompted immediately to change this password.

Since everything is integrated into the boot sequence, the VM will boot up, 
contact a server which assigns its initial configuration, get an IP address
and will join the Grid-Appliance virtual network.

After you log in to the appliance, an X-Windows workspace will appear, and
a connection to an IRC (Internet Relay Chat) server running within the virtual
network of Grid appliances will appear. In this chat window you will be able,
if you so desire, to interact with other users and developers that are also
Grid appliance users to ask questions, post hints, etc. Instructions on how to
join chat rooms are shown in the server's "message of the day" in this window.
The IRC client is called "sirc"; for more information on its use, type man
sirc on a separate terminal window, or /help within the chat window.

EXAMPLES
---------

Some examples of how to run applications in the Condor environment are available 
at /home/condor/examples. Please refer to the Condor manual available the Condor
website http://www.cs.wisc.edu/condor/ for detailed documentation on the
different types of Condor "universes" available for job submission (vanilla and
standard are supported by the appliance) and how to prepare job submission
configuration files.

1) This example submits a very simple Perl script (env-sub.pl) through Condor.

- To submit it, first change to the "examples" directory and type:

condor_submit env-sub

- To follow its progress, type:

condor_q

When the job is finished, the standard output is available as env-test.out.ID,
where ID is the cluster number assigned by Condor when you submitted the job.
A log is also created for the job and available as env-test.log.ID

2) This example submits a longer-running computer architecture simulation,
using a tool (SimpleScalar) which has been compiled using Condor libraries.
Applications compiled with Condor libraries run in the "standard" universe, 
which should be the mode of choice for long-running applications for which
you have source and/or object files available. Standard universe applications
benefit from two important features of Condor: periodic checkpointing, and
remote I/O (See the Condor manual for instructions on how to use
condor_compile to produce executables for the standard universe).

- To submit this example, type:

condor_submit sim-standard

This will submit two different simulations to the Condor pool, each with a
different command line argument. 

- To follow its progress, type:

condor_q

When the job is finished, the standard output and error are available inside
the "log" directory as sim-standard.condor.ID.0.out and .ID.0.res for the first
simulation, and as .ID.1.out and .ID.1.res for the second simulation,
where ID is the cluster number assigned by Condor when you submitted the job.

3) This example submits a "vanilla" version of SimpleScalar. Vanilla jobs
have fewer restrictions than "standard": mainly, you don't need to link with
Condor libraries to run them (and the executable file may be smaller, resulting
in smaller transfer times). However, vanilla jobs are not checkpointed, and
files must be explicitly transfered before the job starts and after it
finishes.

- To submit this example, type:

condor_submit sim-vanilla

This will submit two different simulations to the Condor pool, each with a
different command line argument. Note that in sim-vanilla, files are explicitly
transfered, unlike in sim-standard.

- To follow its progress, type:

condor_q

When the job is finished, the standard output and error are available inside
the "log" directory as sim-vanilla.condor.ID.0.out and .ID.0.res for the first
simulation, and as .ID.1.out and .ID.1.res for the second simulation,
where ID is the cluster number assigned by Condor when you submitted the job.


SOME USEFUL COMMANDS
---------------------

Some useful command references:

1) sudo sh (issued from the condor account) allows a user to become "root" 
   on the appliance. Requires typing the same password created for the condor 
   user upon the first login.

2) disablex.sh, enablex.sh: disable (enable) automatic startup of the the X11 
   windowing system upon login (enabled by default).

3) ps -fu root|grep iprouter : to check if the iprouter process which connects 
   to the virtual network is running or not.

4) more /var/log/ipop: To verify whether they appliance is connected through 
   the virtual network or not.  If the size reported is larger than 4, most 
   likely the appliance is connected over the virtual network and is routable. 
   However, if it's less than 4 or if no network size is reported, the 
   machine may not be connected to the virtual network. 

5) To restart connectivity to the virtual network, execute, as root:
   /etc/init.d/ipop restart 

6) To check the status of the condor pool, execute: condor_status
   (note: condor_status may take several seconds to return a list a status
    list, especially on large pools)

7) To submit an example job: "condor_submit env-sub". 
   A sample env-sub file is available at /home/condor/examples

8) To analyze the status of the submitted job run "condor_q -analyze"



KNOWN ISSUES
-------------

The authors would like to emphasize that due to the wide-area virtual network 
and potential contention for resources, jobs may take several minutes to finish 
and return results. Also, although the virtual networking software is able to 
cross several types of firewalls and network address translation devices,
it is possible that the Grid Appliance is unable to join the wide-area virtual 
network if they are behind certain firewalls/NATs, e.g. if they block UDP 
traffic or change port assignments dynamically and frequently.


SUPPORT
--------

Although we do not have the human resources to fully provide support to this 
appliance, we would like to receive your feedback, suggestions, problem 
reports, success stories in running jobs from one or more appliances, etc,
and we will make our best effort to address them.
Instructions on how to join a user's mailing list can be found in:
http://wow.acis.ufl.edu
Alternatively, you may send email to ipop at acis.ufl.edu 
Attaching the /var/log/ipop file will be helpful. 
