#!/bin/bash

clear

APP_NAME="deny_all_wifi"
GO_FILE="deny_all_wifi.go"
INSTALL_PATH="/usr/local/bin/$APP_NAME"

echo "[+] Starting professional build process for $APP_NAME..."

GO_WAS_INSTALLED=false

check_and_install_go() {
    if ! command -v go &> /dev/null; then
        echo "[-] Go compiler not found."
        read -p "[?] Attempt to install Go now? (yes/no): " install_go_choice
        if [[ "$install_go_choice" =~ ^[Yy]$ ]]; then
            echo "[+] Attempting to install Go..."
            if command -v apt-get &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y golang
            elif command -v pacman &> /dev/null; then
                sudo pacman -S --noconfirm go
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y golang
            elif command -v zypper &> /dev/null; then
                sudo zypper install -y go
            else
                echo "[-] Error: No recognized package manager (apt, pacman, dnf, zypper) found."
                echo "[-] Please install Go (golang) manually to build this project."
                exit 1
            fi
            if ! command -v go &> /dev/null; then
                echo "[-] Go installation failed. Please install Go manually and re-run this script."
                exit 1
            fi
            echo "[+] Go installed successfully."
            GO_WAS_INSTALLED=true
        else
            echo "[-] Go is required to build this application. Exiting."
            exit 1
        fi
    else
        echo "[+] Go compiler found."
    fi
}

uninstall_app() {
    echo "[+] Uninstalling $APP_NAME..."
    if [ -f "$INSTALL_PATH" ]; then
        sudo rm "$INSTALL_PATH"
        echo "[+] Removed binary from $INSTALL_PATH."
    else
        echo "[i] Binary not found in $INSTALL_PATH."
    fi

    read -p "[?] Do you also want to remove the configuration file ($APP_NAME.conf) from the current directory? (yes/no): " remove_config_choice
    if [[ "$remove_config_choice" =~ ^[Yy]$ ]]; then
        if [ -f "$APP_NAME.conf" ]; then
            rm "$APP_NAME.conf"
            echo "[+] Removed $APP_NAME.conf."
        else
            echo "[i] Configuration file not found in current directory."
        fi
    fi
    echo "[+] Uninstallation complete."
    exit 0
}

check_and_install_go

GLOBAL_INSTALLED=false
if [ -f "$INSTALL_PATH" ]; then
    GLOBAL_INSTALLED=true
fi

LOCAL_BINARY_EXISTS=false
if [ -f "./$APP_NAME" ]; then
    LOCAL_BINARY_EXISTS=true
fi

action_choice=""

if $GLOBAL_INSTALLED; then
    echo "[i] $APP_NAME is currently installed globally at $INSTALL_PATH."
    read -p "[?] Do you want to 'uninstall' it, 'recompile' and install globally, or 'build_local'? (uninstall/recompile/build_local): " action_choice
    case "$action_choice" in
        [Uu]* ) uninstall_app ;;
        [Rr]* )
                echo "[+] Recompiling and installing globally..."
                ;;
        [Bb]* )
                echo "[+] Building locally..."
                LOCAL_BINARY_EXISTS=false
                ;;
        * ) echo "[-] Invalid choice. Exiting." ; exit 1 ;;
    esac
elif $LOCAL_BINARY_EXISTS; then
    echo "[i] A local binary for $APP_NAME already exists in the current directory."
    read -p "[?] Do you want to 'recompile' it, 'install_global', or 'run' the existing local binary? (recompile/install_global/run): " action_choice
    case "$action_choice" in
        [Rr]* )
                echo "[+] Recompiling local binary..."
                ;;
        [Ii]* )
                echo "[+] Installing globally..."
                GLOBAL_INSTALLED=true
                ;;
        [Uu]* )
                echo "[+] Running existing local binary..."
                chmod +x "./$APP_NAME"
                sudo "./$APP_NAME" "$@"
                exit 0
                ;;
        * ) echo "[-] Invalid choice. Exiting." ; exit 1 ;;
    esac
else
    read -p "[?] No existing installation found. Do you want to 'install_global' or 'build_local'? (install_global/build_local): " action_choice
    case "$action_choice" in
        [Ii]* )
                echo "[+] Installing globally..."
                GLOBAL_INSTALLED=true
                ;;
        [Bb]* )
                echo "[+] Building locally..."
                ;;
        * ) echo "[-] Invalid choice. Exiting." ; exit 1 ;;
    esac
fi

echo "[+] Compiling Go binary..."
go build -ldflags="-s -w" -o "$APP_NAME" "$GO_FILE"

if [ $? -eq 0 ]; then
    echo "[+] Compilation successful."
else
    echo "[-] Compilation failed. Please check your Go installation and source code."
    exit 1
fi

if $GLOBAL_INSTALLED || [[ "$action_choice" =~ ^[Ii]*$ ]]; then
    echo "[+] Installing binary to $INSTALL_PATH..."
    sudo mv "$APP_NAME" "$INSTALL_PATH"
    sudo chmod +x "$INSTALL_PATH"
    echo "[+] Installation complete! You can now run '$APP_NAME' from anywhere."
else
    echo "[i] Binary kept in current directory as './$APP_NAME'."
    chmod +x "./$APP_NAME"
fi

echo "---------------------------------------------------------"
if $GLOBAL_INSTALLED || [[ "$action_choice" =~ ^[Ii]*$ ]]; then
    echo "  Build Finished. Run with: sudo $APP_NAME"
    read -p "[?] Do you want to run the installed application now? (yes/no): " run_choice
    if [[ "$run_choice" =~ ^[Yy]$ ]]; then
        clear
        sudo "$APP_NAME" "$@"
    fi
else
    echo "  Build Finished. Run with: sudo ./$APP_NAME"
    read -p "[?] Do you want to run the local application now? (yes/no): " run_choice
    if [[ "$run_choice" =~ ^[Yy]$ ]]; then
        clear
        sudo "./$APP_NAME" "$@"
    fi
fi

if [ "$GO_WAS_INSTALLED" = true ]; then
    echo "---------------------------------------------------------"
    echo "[?] This script automatically installed the Go compiler to build the app."
    read -p "[?] Would you like to purge Go and all its build dependencies now? (yes/no): " purge_choice
    if [[ "$purge_choice" =~ ^[Yy]$ ]]; then
        echo "[+] Purging Go and build dependencies..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get purge -y golang*
            sudo apt-get autoremove -y
        elif command -v pacman &> /dev/null; then
            sudo pacman -Rs --noconfirm go
        elif command -v dnf &> /dev/null; then
            sudo dnf remove -y golang
        elif command -v zypper &> /dev/null; then
            sudo zypper remove -y go
        fi
        echo "[+] Build environment purged."
    fi
fi

if $GLOBAL_INSTALLED || [[ "$action_choice" =~ ^[Rr]*$ ]]; then
    echo "[+] Cleaning up temporary build artifacts..."
    rm -f "$APP_NAME" 2>/dev/null
fi
echo "---------------------------------------------------------"