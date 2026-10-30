#!/bin/bash
# paquetes.sh : Fase 2 del plan de optimización. Uso: sudo system/paquetes.sh
# 1) paquetes nuevos, 2) salud de los discos, 3) prueba en caliente del APST del NVMe con bench antes y después.
# La prueba del APST no persiste: el reinicio la deshace. Su resultado decide si la regla udev entra en el paquete.
set -uo pipefail
[ "$EUID" = 0 ] && [ -n "${SUDO_USER:-}" ] || { echo "uso: sudo $0" >&2; exit 1; }
U=$SUDO_USER; H=$(getent passwd "$U" | cut -d: -f6); R=$(dirname "$(readlink -f "$0")")
LOG=$H/inspdell-logs/2-paquetes-$(date +%F-%H%M).log
exec > >(tee -a "$LOG") 2>&1
bench() { runuser -u "$U" -- env HOME="$H" "$R/bench" "$1" | grep -E '^(NVMe|getppid|APST)'; }

echo "== 1. Paquetes (con -Syu: en Arch no se instala sobre una base vieja)"
rmdir /var/cache/pacman/pkg/download-* 2>/dev/null   # restos vacíos de descargas cortadas; -Sc fallaba con ellos
pacman -Syu --needed intel-ucode intel-media-driver libva-utils wireless-regdb pacman-contrib \
    smartmontools nvme-cli linux-lts || { echo "pacman falló: no sigo."; exit 1; }

echo "== 2. Salud de los discos"
nvme smart-log /dev/nvme0
nvme id-ctrl /dev/nvme0 | grep -E '^(apsta|ps +[0-9])'
smartctl -H -A /dev/sda

echo "== 3. Prueba del APST"
Q=/sys/class/nvme/nvme0/power/pm_qos_latency_tolerance_us
apst() { nvme get-feature /dev/nvme0 -f 0x0c -H | head -2 | tr "\n\t" "  "; }
echo "antes: $(apst) · pm_qos $(cat $Q)"; bench 2-apst-antes
echo 0 > "$Q"; sleep 1
echo "con pm_qos=0: $(apst)"; journalctl -k --since=-1min -o cat --no-pager | grep -i nvme
if ! apst | grep -q Disabled; then
    nvme set-feature /dev/nvme0 -f 0x0c -v 0
    echo "con set-feature: $(apst)"
fi
bench 2-apst-despues

chown -R "$U:" "$H/inspdell-logs"
echo "== Listo. Reinicia para cargar el microcódigo nuevo (eso deshace la prueba del APST)."
