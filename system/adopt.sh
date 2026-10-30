#!/bin/bash
# adopt.sh : Fase 3 del plan de optimización. GRUB limpio, paquete inspdell-system y /etc de vuelta a fábrica.
# Uso: cd system/inspdell-system && makepkg -f && cd .. && sudo ./adopt.sh
# Mientras corre, deja un `sudo -i` abierto en otra TTY (Ctrl+Alt+F3). Todo lo que toca queda antes en
# /root/inspdell-backup-<fecha>.tar. Es de un solo uso.
set -uo pipefail
[ "$EUID" = 0 ] && [ -n "${SUDO_USER:-}" ] || { echo "uso: sudo $0" >&2; exit 1; }
U=$SUDO_USER; H=$(getent passwd "$U" | cut -d: -f6); R=$(dirname "$(readlink -f "$0")")
LOG=$H/inspdell-logs/3-adopt-$(date +%F-%H%M).log
exec > >(tee -a "$LOG") 2>&1
B=/root/inspdell-backup-$(date +%F-%H%M).tar
falla() { echo "!! $*: no sigo. Respaldo en $B"; chown -R "$U:" "$H/inspdell-logs"; exit 1; }

PKG=$(ls -t "$R"/inspdell-system/inspdell-system-*.pkg.tar.zst 2>/dev/null | head -1)
[ -n "$PKG" ] || { echo "falta el paquete: cd $R/inspdell-system && makepkg -f"; exit 1; }
[ -z "$(bsdtar -tvf "$PKG" | awk '$3 != "root" || $4 != "root"')" ] || { echo "el paquete tiene archivos que no son de root"; exit 1; }
[ "$(passwd -S root | cut -d' ' -f2)" = P ] ||
    { echo "root no tiene contraseña y el initramfs nuevo la pide en emergencias: corre 'sudo passwd root'"; exit 1; }

echo "== 0. Respaldo en $B"
efibootmgr -v
tar -cf "$B" /etc/grub.d /etc/default/grub /boot/grub/grub.cfg /boot/EFI /etc/sudoers /etc/tlp.conf /etc/tlp.d \
    /etc/lightdm /etc/hosts /etc/pacman.conf /etc/locale.gen /etc/mkinitcpio.conf /etc/environment /etc/makepkg.conf.d \
    /etc/tpm2-tss/fapi-profiles /etc/NetworkManager/conf.d /etc/systemd/zram-generator.conf /etc/sysctl.d \
    /etc/udev/rules.d /etc/systemd/system/wifi-watchdog.service /usr/local/bin/wifi-watchdog.sh || falla "el respaldo"

echo "== 1. GRUB: fuera grub-customizer, scripts y /etc/default/grub de fábrica, ESP a la versión del paquete"
cd /etc/grub.d || exit 1
for f in * .script_sources.txt; do pacman -Qoq "/etc/grub.d/$f" >/dev/null 2>&1 || { echo "  - $f"; rm -rf -- "$f"; }; done
cd /
pacman -S --noconfirm grub || falla "pacman -S grub"
bsdtar -xOf "/var/cache/pacman/pkg/grub-$(pacman -Q grub | cut -d' ' -f2)-x86_64.pkg.tar.zst" etc/default/grub > /etc/default/grub ||
    falla "sacar /etc/default/grub del paquete"
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=arch --no-nvram || falla "grub-install"
for l in 'Windows Boot Manager' cachyos; do       # entradas EFI muertas: \EFI\Microsoft ya no existe, cachyos tampoco
    n=$(efibootmgr | sed -n "s/^Boot\([0-9A-F]\{4\}\)\* $l\t.*/\1/p")
    [ -z "$n" ] || efibootmgr -q -b "$n" -B
done
rm -rf /boot/EFI/cachyos

echo "== 2. Paquete inspdell-system (su .install regenera grub.cfg)"
pacman -U --noconfirm "$PKG" || falla "pacman -U"
grub-script-check /boot/grub/grub.cfg || { tar -xf "$B" -C / boot/grub/grub.cfg; falla "grub.cfg nuevo inválido; restaurado el de antes"; }
grep -oE "^\s*(menuentry|submenu) ['\"][^'\"]+" /boot/grub/grub.cfg

echo "== 3. sudoers de fábrica, solo si el drop-in cubre todas las líneas propias"
activas() { grep -vE '^\s*(#|$)' "$1" | sort -u; }
propias=$(comm -23 <(activas /etc/sudoers) <(activas /etc/sudoers.pacnew) | comm -23 - <(activas /etc/sudoers.d/90-inspdell))
if [ -n "$propias" ]; then
    echo "sudoers tiene líneas propias que el drop-in no cubre; no lo toco:"; echo "$propias"
else
    mv /etc/sudoers /etc/sudoers.antes && mv /etc/sudoers.pacnew /etc/sudoers
    if visudo -c >/dev/null && sudo -l -U "$U" | grep -q '(ALL : ALL) ALL'; then
        rm /etc/sudoers.antes; echo "sudoers de fábrica + drop-in: $U conserva sudo"
    else
        mv /etc/sudoers.antes /etc/sudoers; falla "sudo no quedaba bien; sudoers restaurado"
    fi
fi

echo "== 4. Fuera lo suelto que ya trae el paquete"
rm -fv /etc/systemd/zram-generator.conf /etc/sysctl.d/99-zram-tuning.conf /etc/udev/rules.d/99-{qca9377-pm,rtl8106e-aspm}.rules \
    /etc/tlp.d/10-wifi-qca9377.conf /etc/NetworkManager/conf.d/{dhcp,wifi-powersave}.conf \
    /etc/systemd/system/multi-user.target.wants/wifi-watchdog.service /etc/systemd/system/wifi-watchdog.service \
    /usr/local/bin/wifi-watchdog.sh
systemctl daemon-reload
systemctl restart wifi-watchdog
systemctl start fstrim.timer paccache.timer

echo "== 5. Archivos de paquetes de vuelta a fábrica (.pacnew)"
for f in tlp.conf lightdm/lightdm.conf mkinitcpio.conf makepkg.conf.d/rust.conf makepkg.conf.d/fortran.conf \
         tpm2-tss/fapi-profiles/P_ECCP384SHA384.json tpm2-tss/fapi-profiles/P_RSA3072SHA384.json; do
    mv -v "/etc/$f.pacnew" "/etc/$f"
done
rm -v /etc/pacman.d/mirrorlist.pacnew          # trae todos los servidores comentados; la lista actual es la buena
grep -E '[[:space:]](nas|lab)$' /etc/hosts >> /etc/hosts.pacnew && mv -v /etc/hosts.pacnew /etc/hosts
sed -i '/^PROCESSING=/d' /etc/environment      # la ruta de Processing ya no existe

echo "== 6. pacman.conf y locale.gen: se editan a mano por diseño, sobre el .pacnew"
sed -i -e 's/^#Color$/Color/' -e '/^ParallelDownloads/a ILoveCandy' -e 's/^#IgnorePkg *=.*/IgnorePkg = tailscale/' \
       -e '/^#\[multilib\]/,+1 s/^#//' /etc/pacman.conf.pacnew
pacman-conf --config /etc/pacman.conf.pacnew IgnorePkg | grep -qx tailscale &&
    pacman-conf --config /etc/pacman.conf.pacnew --repo-list | grep -qx multilib || falla "pacman.conf nuevo"
mv -v /etc/pacman.conf.pacnew /etc/pacman.conf
sed -i 's/^#en_CA.UTF-8 UTF-8/en_CA.UTF-8 UTF-8/' /etc/locale.gen.pacnew && mv -v /etc/locale.gen.pacnew /etc/locale.gen
locale-gen && localectl set-locale LANG=en_CA.UTF-8   # hoy la línea era inválida y todo corría en C.UTF-8

echo "== 7. sshd fuera e initramfs con los ganchos systemd"
systemctl disable --now sshd
mkinitcpio -P || { tar -xf "$B" -C / etc/mkinitcpio.conf; mkinitcpio -P; falla "mkinitcpio con el .pacnew; restaurado el de antes"; }

echo "== 8. Comprobación"
pacman -Qkk inspdell-system | tail -1
echo ".pacnew que quedan: $(find /etc -name '*.pacnew' | wc -l)"
chown -R "$U:" "$H/inspdell-logs"
echo "== Listo. En una terminal NUEVA: sudo -l (debe salir '(ALL : ALL) ALL'). Si sale, reinicia."
