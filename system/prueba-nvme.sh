#!/bin/bash
# prueba-nvme.sh : de dónde salen los 39 ms del NVMe tras reposo. Uso: sudo system/prueba-nvme.sh (tras reiniciar)
# El APST quedó descartado en paquetes.sh (apagado, la latencia siguió en 38,7 ms). Aquí se apagan uno a uno
# los ahorros del enlace PCIe (los activa la BIOS) y se mide con bench. Todo se deshace al reiniciar.
set -uo pipefail
[ "$EUID" = 0 ] && [ -n "${SUDO_USER:-}" ] || { echo "uso: sudo $0" >&2; exit 1; }
U=$SUDO_USER; H=$(getent passwd "$U" | cut -d: -f6); R=$(dirname "$(readlink -f "$0")")
LOG=$H/inspdell-logs/2-nvme-$(date +%F-%H%M).log
exec > >(tee -a "$LOG") 2>&1
L=/sys/class/nvme/nvme0/device/link
bench() { echo "== $1 · $(cd $L && grep -H . * | tr '\n' ' ')"; runuser -u "$U" -- env HOME="$H" "$R/bench" "2-nvme-$1" | grep -E '^(NVMe|getppid)|microcode'; }

bench todo
echo 0 > $L/l1_2_aspm; echo 0 > $L/l1_2_pcipm; bench sin-l1.2
echo 0 > $L/l1_aspm; bench sin-l1
echo 0 > $L/clkpm; bench sin-clkpm
chown -R "$U:" "$H/inspdell-logs"
