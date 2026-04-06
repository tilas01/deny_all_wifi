# deny_all_wifi v1.2.0: Bettercap ARP.Ban Auto-Execution Module

A professional, automated wrapper designed to streamline network security testing using Bettercap's `arp.ban` module. **deny_all_wifi** simplifies complex network auditing tasks into a reliable, automated workflow.

Originally developed as a private Bash tool, this project has been completely rewritten in **Go** to provide a robust, high-performance, and feature-rich public application.

## Table of Contents
- [Requirements](#requirements)
- [Project Overview](#project-overview)
- [Legal Warning & Disclaimer](#legal-warning--disclaimer)
- [How It Works](#how-it-works)
- [Features](#features)
- [Dependency Lists](#dependency-lists)
- [Installation](#installation)
  - [Automated Build & Install](#automated-build--install)
- [Usage](#usage)
- [Configuration](#configuration)
- [Credits](#credits)
- [License](#license)

---

## Requirements
To use this tool, your system must meet the following criteria:
*   **Operating System:** Linux (Debian, Arch, Fedora, or OpenSUSE based distributions).
*   **Privileges:** Root/Sudo access is mandatory.
*   **Hardware:** A Wi-Fi adapter capable of monitor mode (though managed mode often works for ARP tasks).
*   **Software Dependencies:** 
    *   **Runtime:** `bettercap`, `macchanger`, `iproute2`.
    *   **Build:** `golang` (only required if compiling from source).

> **Note:** The application performs a dependency check upon launch. If tools are missing, the software will provide guidance or offer to install them via your system package manager.

## Project Overview
**deny_all_wifi** is an automation utility that simplifies the process of performing ARP spoofing and Denial of Service (DoS) testing. It eliminates the need for manual command construction by automatically scanning for wireless interfaces, randomizing hardware addresses for OPSEC, and deploying a pre-configured Bettercap attack sequence.

## Legal Warning & Disclaimer
**[!] IMPORTANT: READ CAREFULLY [!]**

This software is for **educational and authorized security testing purposes only**. 

*   **DO NOT** run this tool on any network you do not own or have explicit, written permission from the owner to test.
*   Unauthorized access to or disruption of a network is illegal in most jurisdictions.
*   The developers assume no liability and are not responsible for any misuse or damage caused by this program.

### Auto-Installation Disclaimer
This tool includes a feature to auto-install missing dependencies via your system's package manager. There is no manual toggle for this once the process is confirmed; by selecting "yes" when prompted, you authorize the script to modify your system packages.

## How It Works
The program follows a logical security workflow:
1.  **Privilege Check:** Verifies root/sudo access (required for raw socket manipulation).
2.  **Interface Selection:** Scans the system for Wi-Fi adapters and displays their IPv4, IPv6, and Gateway information in a neat table.
3.  **OPSEC (MAC Randomization):** Temporarily takes the selected interface down, randomizes the MAC address using `macchanger`, and brings the interface back up.
4.  **Configuration Loading:** Loads or creates a persistent configuration file stored in your home directory.
5.  **Attack Deployment:** Constructs a Bettercap script based on your profile and launches the `arp.ban` module.

## Features
*   **Automatic Dependency Check:** Detects and offers to install missing tools like `bettercap`, `macchanger`, and `iproute2`.
*   **Intelligent Configuration:** Supports both "Default" quick-start and "Interactive" custom setups.
*   **Persistent Settings:** Saves your preferences to a dedicated directory for future use.
*   **MAC Details Preview:** Displays a clear summary of your Permanent vs. New MAC address.
*   **Universal Installer (`install.sh`):** A professional script that can Build, Install (Globally or Locally), Uninstall, or Recompile the application. It also offers to purge the Go compiler after building to keep your system clean.

## Dependency Lists

### Build Dependencies
Required only to compile the Go code:
*   `golang` (Go Programming Language)

### Runtime Dependencies
Required to execute the application:
*   `bettercap` (Network attack and monitoring framework)
*   `macchanger` (MAC address manipulation)
*   `iproute2` (Standard Linux networking toolkit)

> **Bash Alternative:** For users who wish to avoid installing Go entirely, the original Bash script is located in the `bash/` directory. It offers identical functionality with no build dependencies.

## Installation

### Automated Build & Install
The easiest way to install is using the provided `install.sh` script. This script will build and install the application globally or locally.

1.  Clone the repository:
    ```bash
    git clone https://github.com/tilas01/deny_all_wifi.git
    cd deny_all_wifi
    ```
2.  Run the build script:
    ```bash
    cd go
    chmod +x install.sh
    ./install.sh
    ```
3.  Follow the prompts to either install globally (to `/usr/local/bin`) or keep the binary local.

## Usage

### If Installed Globally:
Simply run the command from any terminal:
```bash
sudo deny_all_wifi
```

### If Running Locally:
Run the compiled binary directly:
```bash
sudo ./deny_all_wifi
```

### Workflow:
1.  Select your Wi-Fi interface by its number in the table.
2.  Confirm your configuration profile.
3.  Review the MAC address change details.
4.  Launch the attack.
5.  **Press `Ctrl+C`** at any time to stop the attack and return the network to normal.

## Configuration
Regardless of whether you install the application globally or run it as a local binary from the current path, the configuration file is stored in a centralized directory to ensure your settings persist:

`~/bettercap_conf/deny_all_wifi.conf`

> **Note:** This shared configuration path allows you to switch between the Go and Bash versions seamlessly without losing your preferences.

| Setting | Description |
| :--- | :--- |
| `fullduplex` | Attack both the target and the access point. |
| `sniff_traffic` | Enable network traffic sniffing/logging. |
| `spoof_internal` | Enable ARP spoofing for local LAN traffic. |
| `whitelist` | A comma-separated list of IPs or MACs to ignore. |

## Credits
*   **tilas01**: Project Owner, Lead Developer, and Original Concept.
*   **Google Gemini**: World-class AI coding assistant.

> **Note:** Artificial Intelligence (**Google Gemini**) was utilized as a resource for researching syntax, documentation standards, and architectural best practices. Only small, specific segments of the code and descriptive text within this repository are entirely AI-generated.

## License
This project is licensed under the **MIT License**. See the `LICENSE` file for details.

---
*Disclaimer: This tool is intended for use by security professionals and researchers.*