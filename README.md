# 📡 Amarisoft LTE Software Package

![Version](https://img.shields.io/badge/Version-2025--12--12-blue)
![Platform](https://img.shields.io/badge/Platform-Linux-green)
![License](https://img.shields.io/badge/License-Non--Commercial-red)

> **Professional LTE/5G Network Software Solution**

---

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [System Requirements](#system-requirements)
- [Installation Guide](#installation-guide)
- [Documentation](#documentation)
- [Licensing](#licensing)
- [Contact](#contact)

---

## 🔍 Overview

This repository contains Amarisoft LTE software packages for deploying complete LTE/5G network infrastructure including:

| Component | Description |
|-----------|-------------|
| **lteenb** | LTE/NR eNodeB/gNodeB base station |
| **ltemme** | LTE MME (Mobility Management Entity) |
| **lteue** | UE Simulator for testing |
| **lteims** | IMS (IP Multimedia Subsystem) |
| **ltewww** | Web interface for monitoring |
| **trx_sdr** | SDR transceiver driver |

---

## ✨ Features

- 🔹 Full LTE/5G standalone and non-standalone support
- 🔹 Multi-cell and multi-UE capability
- 🔹 IMS/VoLTE support
- 🔹 Web-based monitoring interface
- 🔹 SDR hardware compatibility
- 🔹 Comprehensive API documentation

---

## 💻 System Requirements

| Requirement | Specification |
|-------------|---------------|
| **OS** | Fedora / CentOS / Ubuntu Linux |
| **CPU** | x86_64 with AVX2 support |
| **RAM** | Minimum 8GB (16GB recommended) |
| **Network** | Gigabit Ethernet |

---

## 🛠️ Installation Guide

### Step 1: Install OpenSSH

```bash
dnf -y install openssh
systemctl enable sshd
nano /etc/ssh/sshd_config  # Set PermitRootLogin yes
service sshd start
service sshd status
```

### Step 2: Disable Firewall

```bash
systemctl disable firewalld
service firewalld stop
```

### Step 3: Disable SELinux

```bash
perl -p -i -e "s/enforcing/disabled/" /etc/selinux/config
# Or manually edit /etc/selinux/config and set SELINUX=disabled
```

### Step 4: Disable GUI (Optional)

```bash
systemctl enable multi-user.target --force
systemctl set-default multi-user.target
```

### Step 5: Install Required Packages

```bash
dnf -y install wget screen iperf wireshark lm_sensors make gcc \
    lksctp-tools.x86_64 kernel-devel.x86_64 htop tcpdump perl php php-json
```

### Step 6: Verify SCTP Module

```bash
checksctp
```

> ⚠️ If protocol not supported:
> - Check `/etc/modprobe.d/sctp-blacklist.conf`
> - Comment out `blacklist sctp` line
> - Reboot system

### Step 7: Enable HTTP Server

```bash
systemctl enable httpd
service httpd start
service httpd status
```

### Step 8: Run Installation Script

```bash
cd 2025-12-12
chmod +x install.sh
./install.sh
```

---

## 📚 Documentation

Full documentation available in the `/doc` folder:

| Document | Description |
|----------|-------------|
| [lteenb.html](doc/lteenb/lteenb.html) | eNodeB Configuration Guide |
| [ltemme.html](doc/ltemme/ltemme.html) | MME Configuration Guide |
| [lteims.html](doc/ltemme/lteims.html) | IMS Setup Guide |
| [trx_sdr.html](doc/trx_sdr/trx_sdr.html) | SDR Driver Guide |

---

## 📜 Licensing

### 💰 Pricing Plans

| Plan | Duration | Price |
|------|----------|-------|
| 🔸 **Standard** | 1 Month | **$300** |
| 🔸 **Professional** | 1 Year (3 licenses) | **$3,000** |

> 📧 **License required for operation**

---

## 📞 Contact

For licensing inquiries and support:

| Method | Contact |
|--------|---------|
| 📧 **Email** | `nuledsec[at]proton.me` |

---

<div align="center">

**⭐ Star this repo if you find it useful! ⭐**

*Last Updated: 2025-12-12*

</div>
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



The highlights for this release are:
Core network
- 5G MBS Nmbsmf interface
- GUTI change during EPS tracking area update procedure
- ePDG IMEI based emergency call
- IMS auth-int QoP
- multiple improvements to IMS callflow modifiers
RAN
- conditional handover using A3, A4, A5, D1 and T1 events forNR
- R18 uplink TX switching for NR
- multiple MAC timing advance groups in NR
- NTN-TDLA/B/D/C channels
- new optional DL multi layer link adapatation algorithm for LTE
- float16 for TRX driver
UE simulator
- logicalChannelSR-Mask, logicalChannelSR-Prohibit and logicalChannelSR-DelayTimer
- D1 measurement for NR
- conditional handover using A3, A4, A5, D1 and T1 events for NR
- NTN-TDLA/B/D/C channels
- TCP IP simulation
- float16 for TRX driver
- 
# amarisoft-lte
last file 2025-12-12

need license contact to my mail
nuledsec[at]proton.me


1 Month service $400

1 Years service $4000 * 3 license


