#!/bin/sh
# install.sh [--no-pkgs] : deja el escritorio como en este repo. Se puede repetir sin romper nada.
set -eu
R=$(dirname "$(readlink -f "$0")")
C=$HOME/.cache/dotfiles
XFWM=Square       # bordes de ventana: home/.local/share/themes/Square/xfwm4 (colores del tema GTK)

# 1. Paquetes
if [ "${1:-}" != --no-pkgs ]; then
    sudo pacman -S --needed $(grep -v -e '^#' -e '^aur:' "$R/packages.txt")
    yay -S --needed $(sed -n 's/^aur://p' "$R/packages.txt")
fi

# 2. Tema GTK Colloid con radio 0 (bordes cuadrados) + iconos. Para recompilar: borrar ~/.themes/Colloid-*
mkdir -p "$C" "$HOME/.local/share/icons"
if [ ! -d "$HOME/.themes/Colloid-Green-Dark-Everforest" ] || [ ! -d "$HOME/.themes/Colloid-Dark-Gruvbox" ]; then
    [ -d "$C/Colloid-gtk-theme" ] || git clone --depth 1 https://github.com/vinceliuice/Colloid-gtk-theme.git "$C/Colloid-gtk-theme"
    # normal: botones _ □ x en las barras de título GTK (no los círculos estilo Mac)
    (cd "$C/Colloid-gtk-theme" && ./install.sh -c dark -t green --tweaks everforest normal && ./install.sh -c dark --tweaks gruvbox normal)
fi
# Esquinas cuadradas: todo radio fijo a 0 salvo los circulares (radio, switch, avatar). Idempotente.
for f in "$HOME"/.themes/Colloid-*/gtk-[34].0/gtk*.css; do
    sed -i -E '/radius: [^;]*(9999px|99px|50%|100%)/! s/([a-z-]*radius): [^;]+;/\1: 0;/g' "$f"
done
# Iconos: Zafiro (variante de Archcraft) arreglado: sin enlaces rotos y heredando solo temas que existen
if [ ! -d "$HOME/.local/share/icons/Zafiro" ]; then
    tar -C "$HOME/.local/share/icons" --zstd -xf "$R/extras/icons/Zafiro.tar.zst"
    gtk-update-icon-cache -f -q "$HOME/.local/share/icons/Zafiro"
fi

# 3. Cursor Everforest (Gruvbox usa Qogir-Cursor)
if [ ! -d "$HOME/.local/share/icons/everforest-cursors" ]; then
    curl -fsSL https://github.com/talwat/everforest-cursors/releases/download/3212590527/everforest-cursors-variants.tar.bz2 |
        tar xj -C "$HOME/.local/share/icons" everforest-cursors
fi

# 4. Enlazar home/ en ~ fichero a fichero; lo que ya existía se guarda como *.pre-dotfiles
cd "$R/home"
find . -type f | while read -r f; do
    src=$R/home/${f#./} dst=$HOME/${f#./}
    [ "$(readlink -f "$dst")" = "$src" ] && continue
    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ] || [ -L "$dst" ]; then mv "$dst" "$dst.pre-dotfiles"; fi
    ln -s "$src" "$dst"
done
mkdir -p "$HOME/.local/bin" && ln -sfn "$R/bin/theme" "$HOME/.local/bin/theme"
# iconos -symbolic del panel: los hechos a mano (Arch, Spotify, Clipman) y los de bandeja para cualquier app
# (extras/make-tray-symbolic.py); sin regenerar la caché GTK no los ve
tar -C "$HOME/.local/share/icons/hicolor" --zstd -xf "$R/extras/icons/tray-symbolic.tar.zst"
gtk-update-icon-cache -f -t -q "$HOME/.local/share/icons/hicolor"
if [ -d "$HOME/.config/legcord" ] && [ ! -L "$HOME/.config/legcord/quickCss.css" ]; then
    mv "$HOME/.config/legcord/quickCss.css" "$HOME/.config/legcord/quickCss.css.pre-dotfiles" 2>/dev/null || true
    ln -s "$HOME/.config/theme/legcord.css" "$HOME/.config/legcord/quickCss.css"
fi
# Legcord manda su icono de bandeja como imagen (no se puede recolorear): el fijo blanco, sin contador
L=$HOME/.config/legcord/storage/settings.json
[ -f "$L" ] && sed -i 's/"tray": *"[^"]*"/"tray": "dsc-tray"/' "$L"
if command -v spicetify >/dev/null; then
    mkdir -p "$HOME/.config/spicetify/Themes"
    ln -sfn "$R/extras/spicetify/text" "$HOME/.config/spicetify/Themes/text"
    spicetify backup >/dev/null 2>&1 || true   # solo la primera vez; luego ya existe
fi
command -v code >/dev/null && code --install-extension jdinhlife.gruvbox >/dev/null

# 5. XFCE: atajos y panel solo en una instalación nueva (no pisa lo que ya hay)
X=$HOME/.config/xfce4/xfconf/xfce-perchannel-xml
mkdir -p "$X"
cp -n "$R"/xfce/*.xml "$X/"

# 6. Ajustes fijos de XFCE (no cambian con el tema); solo si hay sesión XFCE
if xfconf-query -c xsettings -l >/dev/null 2>&1; then
    xq() { xfconf-query -c "$1" -p "$2" -n -t string -s "$3"; }
    xq xfwm4 /general/theme "$XFWM"
    xfconf-query -c xsettings -p /Xfce/SyncThemes -n -t bool -s false   # que Apariencia no cambie el borde Square
    xq xfwm4 /general/title_font "Roboto 9"
    xq xfwm4 /general/button_layout "|HMC"   # sin el icono de la app a la izquierda (ya está en el panel)
    xq xsettings /Gtk/FontName "Roboto 10"
    xq xsettings /Gtk/MonospaceFontName "Iosevka Nerd Font 10"
    xq xfce4-notifyd /theme Square
    xq xfce4-keyboard-shortcuts '/commands/custom/<Super>space' 'rofi -show drun'
    xq xfce4-keyboard-shortcuts '/commands/custom/<Super>t' "$HOME/.local/bin/tiling"
    s=/screensavers/xfce-personal-slideshow
    xq xfce4-screensaver $s/location "$HOME/.config/theme/walls"
    xq xfce4-screensaver $s/background-color "#000000"
    xq xfce4-screensaver $s/arguments "--location=$HOME/.config/theme/walls --background-color=#000000"
    systemctl --user try-restart xdg-desktop-portal-gtk  # el portal (diálogos de archivos) solo lee gtk.css al arrancar
    "$R/bin/theme" everforest
fi
echo "listo. Login: theme everforest --system"
