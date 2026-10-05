#!/bin/sh
# Experimental; invoke from the board's serial console, after booting the matching FPGA/DT.
set -eu
if [ "$#" -ne 6 ]; then
    echo "Usage: $0 GEM_IF DMA_IF PS_IP/PREFIX FPGA_IP FPGA_MAC SERIAL" >&2
    exit 2
fi
phy=$1 dma=$2 mgmt=$3 fpga_ip=$4 fpga_mac=$5 serial=$6
case "$(cat /proc/device-tree/model 2>/dev/null)" in
    *"ANTSDR E310 Micro-USB"*) ;;
    *) echo "This script is only for the matching old E310 device tree." >&2; exit 1 ;;
esac
[ "$(id -u)" -eq 0 ]
[ "$phy" != "$dma" ]
[ "${mgmt%/*}" != "$fpga_ip" ]
# Do not move interfaces carrying an existing management connection.
for nic in "$phy" "$dma"; do
    ip link show dev "$nic" >/dev/null
    if ip -4 addr show dev "$nic" | grep -q 'inet '; then
        echo "$nic already has an IPv4 address; configure this from the serial console." >&2
        exit 1
    fi
done
# The FPGA MAC must differ from both Linux interface MACs.
for nic in "$phy" "$dma"; do
    if [ "$(cat "/sys/class/net/$nic/address")" = "$fpga_mac" ]; then
        echo "FPGA MAC must differ from Linux interface MACs" >&2; exit 1
    fi
done
[ ! -e /sys/class/net/br-uhd ]
brctl addbr br-uhd
brctl stp br-uhd off
brctl setfd br-uhd 0
# Make the management bridge MAC independent from the PL endpoint.
ip link set dev br-uhd address "$(cat "/sys/class/net/$phy/address")"
brctl addif br-uhd "$phy"
brctl addif br-uhd "$dma"
ip link set dev "$phy" mtu 1500 up
ip link set dev "$dma" mtu 1500 up
ip link set dev br-uhd up
ip addr add "$mgmt" dev br-uhd
if ! /sbin/tune-network-irqs.sh "$phy" "$dma"; then
    echo 'Warning: network IRQ tuning failed; high-rate duplex may overflow' >&2
fi
/sbin/e310_endpoint "$fpga_ip" "$fpga_mac"
# Host discovery receives the FPGA IP; the PS management IP stays separate.
exec /sbin/e310_discovery "$phy" "$fpga_ip" "$fpga_mac" "$serial"
