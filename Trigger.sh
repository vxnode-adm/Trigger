#!/bin/bash

# A Linux-based automated emergency dead man's switch that monitors USB buses for unauthorized devices.

CONFIG_DIR="/etc/usb-panic"
WHITELIST_FILE="$CONFIG_DIR/whitelist.conf"
SCRIPT_PATH="$(readlink -f "$0")"


if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root (sudo $0)."
    exit 1
fi

# FFunction to check and install dependencies (srm and wipe)
install_dependencies() {
    if ! command -v srm &> /dev/null || ! command -v wipe &> /dev/null; then
        echo "[*] Downloading and installing dependencies..."
        if command -v apt-get &> /dev/null; then
            apt-get update -y >/dev/null 2>&1
            apt-get install secure-delete wipe -y >/dev/null 2>&1
        elif command -v dnf &> /dev/null; then
            dnf install secure-delete wipe -y >/dev/null 2>&1
        elif command -v pacman &> /dev/null; then
            pacman -Sy --noconfirm secure-delete wipe >/dev/null 2>&1
        fi
    fi
}

setup_wizard() {
    clear
    echo "====================================================="
    echo " Welcome to the Anti-Forensics Trigger Setup Wizard! "
    echo "====================================================="
    install_dependencies

    mkdir -p "$CONFIG_DIR"



    echo ""
    echo "Connect ALL USB devices you use daily."
    read -p "Are they already connected? (y/n): " response
    

    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "[*] Scanning connected USB devices and creating whitelist..."
        sleep 2


        find /sys/bus/usb/devices/ -name "serial" -exec cat {} \; 2>/dev/null | grep -v '^[[:space:]]*$' | sort -u > "$WHITELIST_FILE"
        

        echo "[OK] Whitelist created successfully at $WHITELIST_FILE!"
        echo "Authorized devices saved:"
        cat "$WHITELIST_FILE"
    else
        echo "[!] Aborted. Connect the devices and run again."
        exit 1
    fi



    echo ""
    echo "[*] Configuring Cron to run this script every 5 minutes for continuous monitoring..."
    # Remove any existing cron jobs for this script to avoid duplicates
    crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH" | crontab -
    
    # Add the new cron job
    (crontab -l 2>/dev/null; echo "*/5 * * * * $SCRIPT_PATH --check") | crontab -
    echo "[OK] Cron configured successfully!"
    exit 0
}


execute_panic() {
    
    LUKS_DEVICES=$(dmsetup ls --target crypt 2>/dev/null | awk '{print $1}')
    
    if [ ! -z "$LUKS_DEVICES" ]; then
        for alvo_luks in $LUKS_DEVICES; do
            cryptsetup luksSuspend "$alvo_luks" >/dev/null 2>&1
        done
        
        echo 1 > /proc/sys/kernel/sysrq 2>/dev/null
        echo o > /proc/sysrq-trigger 2>/dev/null
        exit 0
    fi

    find /tmp -type f -exec srm -f -s {} + >/dev/null 2>&1
    find /var/tmp -type f -exec srm -f -s {} + >/dev/null 2>&1
    find /var/log -type f -exec srm -f -s {} + >/dev/null 2>&1
    find /var/cache -type f -exec srm -f -s {} + >/dev/null 2>&1

    
    # Clean user-specific history and cache files for all users
    TARGET_USERS=(
        "/home/*/.bash_history"
        "/home/*/.zsh_history"
        "/home/*/.config/fish/fish_history"
        "/home/*/.local/share/recently-used.xbel"
        "/home/*/.cache/thumbnails"
        "/root/.bash_history"
    )
    
    for item in "${TARGET_USERS[@]}"; do
        eval current=$item
        for f in $current; do
            if [ -f "$f" ]; then
                srm -f -s "$f" >/dev/null 2>&1
            elif [ -d "$f" ]; then
                find "$f" -type f -exec srm -f -s {} + >/dev/null 2>&1
            fi
        done
    done

    
    echo 1 > /proc/sys/kernel/sysrq 2>/dev/null
    echo o > /proc/sysrq-trigger 2>/dev/null
    exit 0
}



# If the user runs the script with '--check' it performs a check against the whitelist
if [ "$1" == "--check" ]; then
    if [ ! -f "$WHITELIST_FILE" ]; then
        exit 1
    fi

    # Captures the unique serial numbers of currently connected USB devices
    CURRENT_USBS=$(find /sys/bus/usb/devices/ -name "serial" -exec cat {} \; 2>/dev/null | grep -v '^[[:space:]]*$' | sort -u)

    
    while read -r connected_usb; do
        if ! grep -q "^$connected_usb$" "$WHITELIST_FILE"; then
            execute_panic
        fi
    done <<< "$CURRENT_USBS"


elif [ "$1" == "--new" ]; then
    echo "[*] Insert the new USB device you want to whitelist. "
    read -p "Press ENTER when the device is connected."
    find /sys/bus/usb/devices/ -name "serial" -exec cat {} \; 2>/dev/null | grep -v '^[[:space:]]*$' | sort -u >> "$WHITELIST_FILE"

    # Removes any duplicate entries 
    sort -u "$WHITELIST_FILE" -o "$WHITELIST_FILE"
    echo "[OK] New device added to the Whitelist!"
    exit 0

else
    setup_wizard
fi

