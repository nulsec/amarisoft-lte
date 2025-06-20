
Install Guide

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
last file 2025-05-21

need license contact to my mail
nuledsec[at]proton.me


1 Month service $199

1 Years service $3000 * 3 license


