#!/bin/sh
# Split PS GEM and PL AXI DMA processing across the two Cortex-A9 CPUs.
set -eu
phy=${1:-eth0}
dma=${2:-eth1}
case "$(cat /proc/device-tree/model 2>/dev/null)" in
    *"ANTSDR E310 Micro-USB"*) ;;
    *) echo 'IRQ tuning requires the old E310 device tree' >&2; exit 1 ;;
esac
[ "$(id -u)" -eq 0 ]
grep -q '^cpu1 ' /proc/stat
pin_interface() {
    nic=$1 mask=$2
    irqs=$(awk -v nic="$nic" '$NF == nic {sub(/:$/, "", $1); print $1}' /proc/interrupts)
    [ -n "$irqs" ] || { echo "No IRQ found for $nic" >&2; return 1; }
    for irq in $irqs; do
        printf '%s\n' "$mask" > "/proc/irq/$irq/smp_affinity"
        echo "$nic IRQ $irq affinity=$(cat "/proc/irq/$irq/smp_affinity")"
    done
}
pin_interface "$phy" 1
pin_interface "$dma" 2
