#!/bin/bash
# cleanup.sh : limpieza grande (Fase 1 del plan de optimización). Uso: sudo system/cleanup.sh
# 1) instantánea de Timeshift, 2) sistema y 3) home sin preguntar (regenerable u obsoleto),
# 4) lo tuyo preguntando uno por uno, 5) TRIM. Log en ~/inspdell-logs/.
# Rutas medidas en este equipo el 2026-10-29: es de un solo uso, no un limpiador genérico.
set -uo pipefail
shopt -s nullglob dotglob
[ "$EUID" = 0 ] && [ -n "${SUDO_USER:-}" ] || { echo "uso: sudo $0" >&2; exit 1; }
U=$SUDO_USER; H=$(getent passwd "$U" | cut -d: -f6); FZF=$H/.fzf/bin/fzf
mkdir -p "$H/inspdell-logs"; LOG=$H/inspdell-logs/1-cleanup-$(date +%F-%H%M).log
exec > >(tee -a "$LOG") 2>&1
cd "$H" || exit 1

libre() { df -h --output=avail / | tail -1 | tr -d ' '; }
quitar() { local p; p=$(pacman -Qq "$@" 2>/dev/null | tr '\n' ' '); [ -z "$p" ] || pacman -Rns --noconfirm $p; }
borrar() { local d; for d; do [ -e "$d" ] || [ -L "$d" ] || continue; echo "  - $d ($(du -sh "$d" 2>/dev/null | cut -f1))"; rm -rf -- "$d"; done; }
pregunta() { local r; read -rp "¿$1? [s/N] " r </dev/tty; [[ $r == [sS] ]]; }
marcar() { "$FZF" -m --tac --delimiter '\t' --header "$1 · TAB marca, Enter confirma, Esc no borra nada" | cut -f2; }

antes=$(libre); echo "== $(date -Is) · libre en / antes: $antes"
abiertos=""; for n in brave chrome zen zen-bin firefox spotify Unity notion-app insomnia; do pgrep -x "$n" >/dev/null && abiertos+="$n "; done
[ -z "$abiertos" ] || { echo "Cierra antes estas apps (se borran sus cachés o perfiles): $abiertos"; exit 1; }

echo "== 1. Instantánea de Timeshift de / al HDD (red de seguridad; tarda unos minutos)"
if ! timeshift --list --scripted | grep -q 'antes de optimizar'; then
    timeshift --create --comments "antes de optimizar (inspdell)" --scripted || { echo "Timeshift falló: no sigo."; exit 1; }
fi

echo "== 2. Sistema, sin preguntar"
pacman -Sc --noconfirm                       # caché: solo la versión instalada de cada paquete
echo "  coredumps: $(du -sh /var/lib/systemd/coredump | cut -f1)"; rm -f /var/lib/systemd/coredump/*
journalctl --vacuum-size=200M
rm -f "$H/.config/systemd/user/default.target.wants/appimagelauncherd.service"
quitar grub-customizer xpytile-git appimagelauncher web-greeter os-prober $(pacman -Qq | grep -- '-debug$')
T=/root/inspdell-cleanup-$(date +%F).tar
restos=(); for f in /opt/yay-git /etc/default/grub.bak /etc/passwd.OLD /etc/lightdm/web-greeter.yml*; do [ -e "$f" ] && restos+=("$f"); done
[ ${#restos[@]} = 0 ] || { tar -cf "$T" "${restos[@]}" && rm -rf -- "${restos[@]}" && echo "  restos de /etc y /opt en $T"; }
timeshift --delete --snapshot 2024-04-04_15-58-42 --scripted --yes

echo "== 3. Tu home, sin preguntar (cachés y artefactos que se regeneran)"
borrar .npm/_cacache .cache/{google-chrome,BraveSoftware,spotify,pnpm,node,go-build,yay} \
    Repos/pasantia/*/.angular/cache workbench/05_Git_Repos/Forks/PepoMote/*/target \
    "workbench/02_GameDev/Projects/Unity/Proyecto de prueba/Library" \
    workbench/02_GameDev/Projects/Unity/IMX/IMX3-MainUnity-Project/mono_crash.*.blob \
    .vscode-server yay .local/share/Trash/{files,info} \
    .config/chromium .config/nvm .antigen .zcompdump* \
    .p10k.zsh.pre-dotfiles .zshrc.pre-dotfiles .config/{legcord/quickCss.css,rofi/config.rasi,alacritty/alacritty.toml}.pre-dotfiles

echo "== 4. Lo tuyo: decides tú"
pregunta "Quitar Google Chrome y su perfil de 6,3 GB (usas Brave)" && { quitar google-chrome; borrar .config/google-chrome; }
pregunta "Quitar Zen y su perfil" && { quitar zen-browser-bin; borrar .config/zen .cache/zen; }
pregunta "Quitar Firefox Developer y su perfil (~/.mozilla)" && { quitar firefox-developer-edition; borrar .mozilla .cache/mozilla; }
pregunta "Borrar los 3 GB de datos de Cursor (ya no está instalado)" && borrar .cursor .config/Cursor
pregunta "Quitar Notion y sus datos (0,8 GB)" && { quitar notion-app-electron; borrar .config/Notion; }
pregunta "Quitar Insomnia y sus datos" && { quitar insomnia; borrar .config/Insomnia; }
pregunta "Quitar texlive-fontsextra (1,8 GB de fuentes LaTeX)" && quitar texlive-fontsextra
pregunta "Quitar documentación y fuentes de OpenJDK 17/21 (0,6 GB)" && quitar openjdk17-doc openjdk21-doc openjdk17-src openjdk21-src
pregunta "Quitar la toolchain Rust 1.97.1 (stable se queda)" && runuser -u "$U" -- env HOME="$H" rustup toolchain uninstall 1.97.1-x86_64-unknown-linux-gnu
pregunta "Borrar Android SDK, .gradle y .android (3,8 GB; no hay Android Studio)" && borrar android-sdk .gradle .android
pregunta "Borrar la caché de Flutter/Dart (.pub-cache, 1 GB)" && borrar .pub-cache
pregunta "Borrar la caché de Maven (.m2, 0,3 GB)" && borrar .m2

echo "-- Apps instaladas a mano que nada requiere"
sel=$(LC_ALL=C pacman -Qi $(pacman -Qetq) | awk -F': ' '/^Name/{n=$2} /^Description/{d=$2}
    /^Installed Size/{split($2,a," "); v=a[1]; if(a[2]=="GiB")v*=1024; else if(a[2]=="KiB")v/=1024; else if(a[2]=="B")v/=1048576
    printf "%6.0fM\t%s\t%s\n", v, n, d}' | sort -n | marcar "Apps a quitar (con sus dependencias huérfanas)")
[ -z "$sel" ] || pacman -Rns $sel

echo "-- node_modules y target de proyectos"
sel=$(find Repos workbench -maxdepth 6 \( -path '*/IMX3-MainUnity-Project' -o -name .git \) -prune -o \
        -type d \( -name node_modules -o -name target \) -prune -print 2>/dev/null |
      while read -r d; do printf '%s\t%s\n' "$(du -sh "$d" | cut -f1)" "$d"; done | sort -h | marcar "Carpetas de dependencias a borrar")
while read -r d; do [ -n "$d" ] && borrar "$d"; done <<< "$sel"

echo "-- Desktop, Downloads y Videos"
sel=$(du -sh Desktop/* Downloads/* Videos/* 2>/dev/null | sort -h | marcar "Archivos a borrar")
while read -r d; do [ -n "$d" ] && borrar "$d"; done <<< "$sel"

echo "== 5. TRIM del NVMe (el primero en su vida)"
fstrim -v /
echo "== Libre en / antes: $antes · después: $(libre)"
chown -R "$U:" "$H/inspdell-logs"
