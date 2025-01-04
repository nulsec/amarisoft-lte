
Install Guide
1 Requirements
Before proceeding, make sure that you have:

A fast PC. For best performances, an Intel Core i9 CPU with 18 cores and AVX2 support running at a clock of 4 GHz is recommended for a 5G setup.
Appropriate hardware interface(s) to connect your Radio frontend, i.e:
- PCIe port: (1x gen 2 per PCIe SDR50 card)
- PCIe port: (8x gen 2 per PCIe SDR100 card)
- PCIe port: (4x gen 2 per PCIe CPRI card)
- One Gigabit Ethernet port per USRP device such as N2x0
- One USB 3.0 port per USRP device such as B2x0
- One 10 Gigabit Ethernet port per USRP device such as X3x0
Root privileges to be able to install and run the software.
A 64 bit Linux distribution. Fedora 39 is the officially supported distribution.
The following distributions are known as compatible:
Fedora 22 to 39
Cent OS 7
Ubuntu 14 to 22
Your system requires at least GLIBC 2.17.

Internet access as new packages might be required to get installed on your PC.
2 Computer Setup
We strongly advise to restrict the usage of computer for running Amarisoft Software only. Installing or running any other program like graphical user interface can impact real performance of the device.

Amarisoft provides a Fedora recovery image. This image can be used to setup your custom server with Fedora OS. You can find the details in tech academy at https://tech-academy.amarisoft.com/Install_RecoveryUSB.html.

The step by step manual install for Fedora is detailed in the follwoing. For other Linux distributions, you should find the the same packages to install.

Install your OS ISO image on the server.
Install and launch openssh
- dnf -y install openssh
- systemctl enable sshd
- nano /etc/ssh/sshd_config (Set PermitRootLogin yes)
- service sshd start
- service sshd status
Disable firewall
- systemctl disable firewalld
- service firewalld stop
Disable SELinux
- perl -p -i -e "s/enforcing/disabled/" /etc/selinux/config
- or edit the file /etc/selinux/config and edit the line Selinux to SElinux = disabled
Disable graphical GUI
- systemctl enable multi-user.target --force
- systemctl set-default multi-user.target
Install the following packages
- dnf -y install wget screen iperf wireshark lm_sensors make gcc lksctp-tools.x86_64 kernel-devel.x86_64 htop tcpdump perl php php-json
Verify that SCTP kernel module is running
- checksctp
- if it reports that the protocol is not supported
- check if you have a /etc/modprobe.d/sctp-blacklist.conf file
- edit it to comment the ’blacklist sctp’ line
- reboot
Verify that httpd is running
- service httpd status
- if it is not enabled, type
- systemctl enable httpd
- service httpd start
For SW package installation follow the instructions on section See Installation Steps for more details.


# amarisoft-lte
last file 23-12-2024

need license contact to my mail and buy it at
https://nulledsec.mysellix.io/product/amarisoft-license-key-6771618ad8f5b

