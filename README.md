# 📡 Amarisoft LTE Software Package

![Version](https://img.shields.io/badge/Version-2025--12--12-blue)
![Platform](https://img.shields.io/badge/Platform-Linux-green)
![License](https://img.shields.io/badge/License-Non--Commercial-red)

> **Professional LTE/5G Network Software Solution**

---

## 📋 Table of Contents

- [🔍 Overview](#-overview)
- [✨ Features](#-features)
- [💻 System Requirements](#-system-requirements)
- [🛠️ Installation Guide](#️-installation-guide)
- [📚 Documentation](#-documentation)
- [📜 Licensing](#-licensing)
- [📞 Contact](#-contact)

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

### ⚙️ Minimum Components Required

To run the Amarisoft system, you need **at least 3 components**:

| No | Component | Description |
|----|-----------|-------------|
| 1️⃣ | **MME** | Mobility Management Entity - Core network |
| 2️⃣ | **eNB** | Base Station (LTE eNodeB or 5G gNodeB) |
| 3️⃣ | **UE** | User Equipment Simulator |

> ⚠️ **Without these three components, the system will not function properly**

---

### 📋 Available License Types

<details>
<summary><b>🔹 RAN Licenses (Radio Access Network)</b></summary>

| License Name | Description |
|--------------|-------------|
| AMARI LTE NW 600 RAN | LTE Network 600 RAN |
| AMARI LTE NW 1200 RAN | LTE Network 1200 RAN |
| AMARI LTE NW 2000 RAN | LTE Network 2000 RAN |
| AMARI NW 200 RAN | Network 200 RAN |
| AMARI NW 600 RAN | Network 600 RAN |
| AMARI NW 2000 RAN | Network 2000 RAN |
| AMARI NW 4000 RAN | Network 4000 RAN |
| AMARI NW 8000 RAN | Network 8000 RAN |
| AMARI NW 12000 RAN | Network 12000 RAN |
| Old AMARI LTE NW 1200 RAN | Legacy LTE Network 1200 RAN |

</details>

<details>
<summary><b>🔹 RAN VM Licenses (Virtual Machine)</b></summary>

| License Name | Description |
|--------------|-------------|
| AMARI LTE NW 600 RAN VM | LTE Network 600 RAN Virtual Machine |
| AMARI NW 200 RAN VM | Network 200 RAN Virtual Machine |

</details>

<details>
<summary><b>🔹 FR2 RAN Licenses (mmWave)</b></summary>

| License Name | Description |
|--------------|-------------|
| AMARI NW 8000 RAN FR2 | Network 8000 RAN FR2 |
| AMARI NW 2000 RAN FR2 | Network 2000 RAN FR2 |
| AMARI NW 4000 RAN FR2 | Network 4000 RAN FR2 |
| AMARI NW 12000 RAN FR2 | Network 12000 RAN FR2 |

</details>

<details>
<summary><b>🔹 NTN Licenses (Non-Terrestrial Network)</b></summary>

| License Name | Description |
|--------------|-------------|
| AMARI NW 200 RAN NTN | Network 200 RAN NTN |
| AMARI NW 600 RAN NTN | Network 600 RAN NTN |
| AMARI NW 2000 RAN NTN | Network 2000 RAN NTN |
| AMARI NW 4000 RAN NTN | Network 4000 RAN NTN |
| AMARI NW 4000 RAN FR2 NTN | Network 4000 RAN FR2 NTN |
| AMARI NW 8000 RAN NTN | Network 8000 RAN NTN |
| AMARI NW 8000 RAN FR2 NTN | Network 8000 RAN FR2 NTN |
| AMARI NW 12000 RAN FR2 NTN | Network 12000 RAN FR2 NTN |
| 1000xAMARI NW 12000 RAN FR2 NTN | 1000x Network 12000 RAN FR2 NTN |

</details>

<details>
<summary><b>🔹 UE Licenses (User Equipment Simulator)</b></summary>

| License Name | Description |
|--------------|-------------|
| AMARI LTE UE 001 | LTE UE Simulator 1 UE |
| AMARI LTE UE 020 | LTE UE Simulator 20 UEs |
| AMARI LTE UE 064 | LTE UE Simulator 64 UEs |
| AMARI LTE UE 128 | LTE UE Simulator 128 UEs |
| AMARI LTE UE 256 | LTE UE Simulator 256 UEs |
| AMARI LTE UE 1000 | LTE UE Simulator 1000 UEs |
| AMARI UE 001 | UE Simulator 1 UE |
| AMARI UE 064 | UE Simulator 64 UEs |
| AMARI UE 064 II | UE Simulator 64 UEs (Type II) |
| AMARI UE 128 | UE Simulator 128 UEs |
| AMARI UE 256 | UE Simulator 256 UEs |
| AMARI UE 1000 | UE Simulator 1000 UEs |

</details>

<details>
<summary><b>🔹 UE FR2 & NTN Licenses</b></summary>

| License Name | Description |
|--------------|-------------|
| AMARI UE 064 FR2 | UE Simulator 64 FR2 |
| AMARI UE 128 FR2 | UE Simulator 128 FR2 |
| AMARI UE 064 NTN | UE Simulator 64 NTN |
| AMARI UE 256 NTN | UE Simulator 256 NTN |
| AMARI UE 1000 NTN | UE Simulator 1000 NTN |
| AMARI UE 001 NTN | UE Simulator 1 NTN |
| AMARI UE 001 FR2 NTN | UE Simulator 1 FR2 NTN |
| AMARI UE 064 FR2 NTN | UE Simulator 64 FR2 NTN |
| 1000xAMARI UE 064 FR2 NTN | 1000x UE Simulator 64 FR2 NTN |

</details>

<details>
<summary><b>🔹 Core Network Licenses</b></summary>

| License Name | Description |
|--------------|-------------|
| AMARI 4G CORE TM | 4G Core Network (Test Mode) |
| AMARI 4G 5G CORE TM | 4G/5G Core Network (Test Mode) |
| AMARI 4G CORE VM | 4G Core Virtual Machine |
| AMARI 4G 5G CORE VM | 4G/5G Core Virtual Machine |
| AMARI 4G CORE D | 4G Core Deployment |
| AMARI 4G 5G CORE D | 4G/5G Core Deployment |
| 1000xAMARI 4G 5G CORE TM | 1000x 4G/5G Core (Test Mode) |

</details>

<details>
<summary><b>🔹 Small Cell & Base Station Licenses</b></summary>

| License Name | Description |
|--------------|-------------|
| AMARI LTE Small Cell | LTE Small Cell |
| AMARI NR Small Cell | NR Small Cell |
| AMARI Multi IOT Small Cell | Multi IOT Small Cell |
| AMARI LTE One Sector | LTE One Sector |
| AMARI NR One Sector | NR One Sector |
| eNB-200 | eNodeB 200 |
| eNB-BS-SC-400 | eNodeB Base Station Small Cell 400 |
| gNB-BS-SC-2000 | gNodeB Base Station Small Cell 2000 |
| eNB/gNB-BS-SC-2400 | eNB/gNB Base Station Small Cell 2400 |

</details>

<details>
<summary><b>🔹 vRAN Licenses (Virtual RAN)</b></summary>

| License Name | Description |
|--------------|-------------|
| AMARI vRAN | Virtual RAN |
| AMARI LTE vRAN | LTE Virtual RAN |
| AMARI vRAN FR2 | Virtual RAN FR2 |

</details>

<details>
<summary><b>🔹 Special & Internal Licenses</b></summary>

| License Name | Description |
|--------------|-------------|
| AMARI IMS | IP Multimedia Subsystem |
| AMARI N3IWF TM | N3IWF (Test Mode) |
| AMARI NM | Network Management |
| AMARI NW 600 RAN DH | Network 600 RAN DH |
| AMARI License Server | License Server |
| Internal Prob | Internal Probe |
| Internal LTE Sim | Internal LTE Simulator |
| Internal 10 eNB | Internal 10 eNodeB |
| Internal 10 MME | Internal 10 MME |
| Internal 10 UE | Internal 10 UE |
| Internal R&D | Internal Research & Development |

</details>

---

### 💰 Pricing Plans

| Plan | Duration | Price |
|------|----------|-------|
| 🔸 **Standard** | 1 Month (1 licenses) | **$300** |
| 🔸 **Professional** | 1 Year (1 licenses) | **$3,000** |

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


