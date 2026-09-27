#!/usr/bin/env bash
# DESCRIPTION============================================================================================
# Part of the labscreen addon.
# Sends IP address + CPU/RAM load over serial 9600.
# Infinite loop for optimization purposes. Reopening the serial port will result in visual complications.
# END_DESCRIPTION========================================================================================
set -euo pipefail

# CONFIG===============================================================================
# input your arduino stable path into SERIAL_DEV
# To find your arduino stable path use: ls -l /dev/serial/by-id/
SERIAL_DEV="/dev/serial/by-id/usb-Arduino__www.arduino.cc__0043_XXXXXXXXXXXX-if00"
BAUD=9600 # if you intend to change BAUD also change it in lcd_stats_display.ino line 8
INTERVAL=5   # seconds between updates
# END_CONFIG===========================================================================

get_ip() {
    # SECURITY_RELEVANT: Local routing-table lookup => no packet sent, works offline
    ip route get 1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="src") print $(i+1)}'
}

get_cpu_percent() {
    read -r _ a1 b1 c1 idle1 iowait1 irq1 softirq1 steal1 _ < /proc/stat
    sleep 0.5
    read -r _ a2 b2 c2 idle2 iowait2 irq2 softirq2 steal2 _ < /proc/stat

    local idleall1=$((idle1 + iowait1))
    local idleall2=$((idle2 + iowait2))
    local total1=$((a1 + b1 + c1 + idle1 + iowait1 + irq1 + softirq1 + steal1))
    local total2=$((a2 + b2 + c2 + idle2 + iowait2 + irq2 + softirq2 + steal2))

    local dtotal=$((total2 - total1))
    local didle=$((idleall2 - idleall1))

    if [ "$dtotal" -le 0 ]; then
        echo 0
    else
        echo $(( (100 * (dtotal - didle)) / dtotal ))
    fi
}

get_ram_percent() {
    free | awk '/Mem:/{printf "%d", ($3/$2)*100}'
}

if [ ! -e "$SERIAL_DEV" ]; then
    echo "Serial device $SERIAL_DEV not found. Check: ls /dev/serial/by-id/" >&2
    exit 1
fi

stty -F "$SERIAL_DEV" "$BAUD" raw -echo

# Open once, keep open for the life of the script.
exec 3<>"$SERIAL_DEV"

# Await arduino reboot following link.
sleep 2

while true; do
    ip_addr=$(get_ip)
    cpu=$(get_cpu_percent)
    ram=$(get_ram_percent)

    printf 'IP:%s\n' "$ip_addr" >&3
    printf 'ST:CPU:%2d%%RAM:%2d%%\n' "$cpu" "$ram" >&3

    sleep "$INTERVAL"
done
