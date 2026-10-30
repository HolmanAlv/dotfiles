#!/bin/bash
# migrate-home.sh : Fase 4 del plan. ~ pasa del HDD al NVMe (menos workbench/02_GameDev) y el HDD se monta en ~/HDD.
# Copia sin borrar nada del HDD. Tres pasos:
#   1) sudo migrate-home.sh copia      con tu sesión abierta: la copia lenta
#   2) migrate-home.sh final           reinicia y, en la pantalla de login SIN entrar, Ctrl+Alt+F3 como root
#   3) sudo migrate-home.sh ordenar    tras reiniciar: ~/HDD queda con GameDev, Respaldo y home-anterior
set -uo pipefail
shopt -s dotglob nullglob
[ "$EUID" = 0 ] || { echo "uso: sudo $0 copia|ordenar  ·  como root: $0 final" >&2; exit 1; }
U=$(stat -c %U "$(readlink -f "$0")"); H=$(getent passwd "$U" | cut -d: -f6)
N=/mnt/nvroot                          # la raíz del NVMe sin el HDD encima
HDD_UUID=dd3c6e98-12ab-42cd-9995-df8583986888
# Exclusión anclada con / (sin ella rsync saltaría cualquier carpeta 02_GameDev); -x no entra en otros montajes.
# P protege del --delete los logs de este script, que solo existen en el NVMe.
copiar() { rsync -aHAXSx --info=progress2 --exclude=/workbench/02_GameDev --filter='P /inspdell-logs/4-*' "$@" "$H/" "$N$H/"; }
nvroot() {
    mkdir -p "$N"; mountpoint -q "$N" || mount --bind / "$N" || exit 1
    mkdir -p "$N$H/inspdell-logs"; chown "$U:" "$N$H" "$N$H/inspdell-logs"; chmod 700 "$N$H"
    LOG=$N$H/inspdell-logs/4-$1-$(date +%F-%H%M).log; exec > >(tee -a "$LOG") 2>&1
}

case ${1:-} in
copia)
    [ -n "${SUDO_USER:-}" ] || { echo "este paso va con sudo desde tu sesión"; exit 1; }
    # Lo que hubiera en /home del NVMe quedó tapado al montar el HDD encima: se aparta antes de copiar
    mkdir -p "$N"; mountpoint -q "$N" || mount --bind / "$N" || exit 1
    if [ ! -e "$N/root/.inspdell-home-tapado" ]; then
        tapado=("$N"/home/*)
        if [ ${#tapado[@]} -gt 0 ]; then
            T=$N/root/home-tapado-$(date +%F); mkdir -p "$T"; mv -- "${tapado[@]}" "$T"/
            echo "Había restos bajo /home en el NVMe ($(du -sh "$T" | cut -f1)): movidos a /root/home-tapado-$(date +%F)"
        fi
        touch "$N/root/.inspdell-home-tapado"
    fi
    nvroot copia
    fstrim -v /
    total=$(copiar -n --stats | awk -F': ' '/^Total file size/ {gsub(/[^0-9]/, "", $2); print $2}')
    libre=$(df -B1 --output=avail / | tail -1)
    echo "== A copiar: $((total / 2**30)) GiB · libre en el NVMe: $((libre / 2**30)) GiB"
    [ "$total" -lt $((libre - 40 * 2**30)) ] || { echo "No cabe dejando 40 GiB libres: no copio."; exit 1; }
    copiar || [ $? = 24 ] || { echo "rsync falló"; exit 1; }   # 24: archivos que desaparecieron mientras copiaba
    echo "== Copia lista. Reinicia y, en la pantalla de login SIN entrar, Ctrl+Alt+F3 como root: $0 final"
    ;;
final)
    [ -z "${SUDO_USER:-}" ] || { echo "este paso va como root en una TTY (Ctrl+Alt+F3, usuario root), no con sudo"; exit 1; }
    if pgrep -u "$U" >/dev/null; then
        echo "Todavía hay procesos de $U: tu sesión sigue abierta. Lo más simple: reinicia y, en la pantalla de"
        echo "login sin entrar, Ctrl+Alt+F3 como root y repite este comando. Procesos:"
        pgrep -u "$U" -l; echo "(si no se van solos: loginctl terminate-user $U)"; exit 1
    fi
    cd /
    nvroot final
    [ -d "$N$H/.config" ] || { echo "No veo la copia del paso 1 en el NVMe: corre antes 'sudo $0 copia'."; exit 1; }
    mkdir -p "$H/HDD"; chown "$U:" "$H/HDD"   # el punto de montaje viaja con la copia; findmnt --verify exige que exista
    copiar --delete || [ $? = 24 ] || { echo "rsync falló: fstab sin tocar, todo sigue como antes."; exit 1; }
    cp /etc/fstab /etc/fstab.bak
    awk -v u="$HDD_UUID" -v m="$H/HDD" 'BEGIN {OFS="\t"} $1 == "UUID=" u && $2 == "/home" {
        $2 = m; $4 = "noatime,nofail,x-systemd.automount,x-systemd.idle-timeout=10min,x-systemd.device-timeout=10s"} 1' \
        /etc/fstab.bak > /etc/fstab
    diff /etc/fstab.bak /etc/fstab
    if ! findmnt --verify --tab-file /etc/fstab || ! grep -q "$H/HDD" /etc/fstab; then
        cp /etc/fstab.bak /etc/fstab; echo "fstab nuevo inválido: restaurado, nada cambió."; exit 1
    fi
    echo "== Listo: reinicio en 5 s. Al volver, entra y corre: sudo $0 ordenar"
    sleep 5; systemctl reboot
    ;;
ordenar)
    [ -n "${SUDO_USER:-}" ] || { echo "este paso va con sudo desde tu sesión"; exit 1; }
    D=$H/HDD; ls "$D" >/dev/null       # dispara el automontaje
    findmnt -T "$D/." -no SOURCE | grep -q sda || { echo "~/HDD no está montado (¿reiniciaste tras el paso 2?)"; exit 1; }
    findmnt -T "$H" -no SOURCE | grep -q nvme || { echo "~ no está en el NVMe"; exit 1; }
    LOG=$H/inspdell-logs/4-ordenar-$(date +%F-%H%M).log; exec > >(tee -a "$LOG") 2>&1
    [ -d "$D/$U" ] && mv -v "$D/$U" "$D/home-anterior"
    [ -d "$D/home-anterior/workbench/02_GameDev" ] && mv -v "$D/home-anterior/workbench/02_GameDev" "$D/GameDev"
    mkdir -p "$D/Respaldo"
    chown "$U:" "$D" "$D/Respaldo"   # la raíz del disco pasa a ser tuya; timeshift y lost+found siguen de root
    ls -la "$D"
    df -h / "$D"
    ;;
*) echo "uso: sudo $0 copia|ordenar  ·  como root en una TTY: $0 final" >&2; exit 1 ;;
esac
