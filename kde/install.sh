#!/bin/sh
# install.sh: puts Neon Ninja on this machine and applies it. Safe to repeat.
# Everything it touches is saved first, and neon-ninja-remove puts all of it back.
# Files are copied, nothing points to the repo.
set -eu
R=$(dirname "$(readlink -f "$0")")
D=$HOME/.local/share/neon-ninja
B=$D/backup

# The desktop rewrites these on its own, so they are saved even if this script never edits them
CONFIGS='.config/kdeglobals .config/kwinrc .config/kwinrulesrc .config/plasmarc .config/plasmashellrc
.config/plasma-org.kde.plasma.desktop-appletsrc .config/kglobalshortcutsrc .config/breezerc .config/darklyrc
.config/kscreenlockerrc .config/kcminputrc .config/krunnerrc .config/ksplashrc .config/Trolltech.conf
.config/gtkrc .config/gtkrc-2.0 .config/xsettingsd .config/gtk-3.0/gtk.css .config/gtk-3.0/settings.ini
.config/gtk-3.0/colors.css .config/gtk-3.0/window_decorations.css .config/gtk-4.0/gtk.css
.config/gtk-4.0/settings.ini .config/gtk-4.0/colors.css .config/gtk-4.0/window_decorations.css
.config/kdedefaults .config/spicetify/config-xpui.ini'

# Generated here rather than copied from home/
GENERATED='.local/share/plasma/look-and-feel/org.holman.tokyored .local/share/plasma/look-and-feel/org.holman.neonninja
.local/share/color-schemes/TokyoRed.colors .local/share/fonts/neon-ninja .local/share/icons/Zafiro
.local/share/plasma_icons .local/share/icons/Zafiro-Red .local/share/icons/Zafiro-Red-Lines .local/share/ksysguard/sensorfaces/org.holman.neonbars
.config/plasma-workspace/env/neon-ninja-restore.sh'

# $1 is relative to $HOME: keep what is there now, or note that nothing was
remember() {
    grep -qxF -- "$1" "$B/list" 2>/dev/null && return 0
    echo "$1" >> "$B/list"
    if [ -e "$HOME/$1" ] || [ -L "$HOME/$1" ]; then
        (cd "$HOME" && cp -a --parents -- "$1" "$B/files/")
    else
        echo "$1" >> "$B/absent"
    fi
}

# A finished removal leaves an old backup behind: this is a new install, save the desktop as it is today
[ ! -f "$B/restored" ] || rm -rf "$B"

if [ ! -f "$B/list" ]; then
    # plasmashellrc only reaches the disk when plasmashell exits
    [ -n "${NO_SESSION:-}" ] || systemctl --user restart plasma-plasmashell.service
    mkdir -p "$B/files"
    : > "$B/absent"
fi
for f in $CONFIGS $GENERATED; do remember "$f"; done

if [ -d "$R/home" ]; then
    (cd "$R/home" && find . -type f | sed 's|^\./||') | while IFS= read -r f; do
        remember "$f"
        mkdir -p "$HOME/$(dirname "$f")"
        cp "$R/home/$f" "$HOME/$f"
    done
fi

mkdir -p "$HOME/.local/bin"
cp "$R/neon-ninja-remove" "$HOME/.local/bin/neon-ninja-remove"
chmod +x "$HOME/.local/bin/neon-ninja-remove"

[ -z "${NO_SESSION:-}" ] || exit 0

# Fonts: downloaded rather than kept in the repo, only the families used (the full Moralerspace package is 1 GB)
F=$HOME/.local/share/fonts/neon-ninja
if [ ! -d "$F" ]; then
    T=$(mktemp -d)
    G=https://raw.githubusercontent.com/google/fonts/main/ofl
    curl -fsSL -o "$T/MPLUS1[wght].ttf" "$G/mplus1/MPLUS1%5Bwght%5D.ttf"
    curl -fsSL -o "$T/DotGothic16-Regular.ttf" "$G/dotgothic16/DotGothic16-Regular.ttf"
    curl -fsSL -o "$T/m.zip" https://github.com/yuru7/moralerspace/releases/download/v2.0.0/Moralerspace_v2.0.0.zip
    echo "56175ee16373ba1a3d2fd5ec46f3b0b6bf0412be7db1481ec7dee757f2e3d557  $T/m.zip" | sha256sum -c --quiet
    bsdtar -xf "$T/m.zip" -C "$T" --strip-components=1 '*/MoralerspaceNeon-*'
    rm "$T/m.zip"
    mkdir -p "$(dirname "$F")"
    mv "$T" "$F"
    chmod 755 "$F"
    fc-cache "$F"
fi
[ -f "$F/DotGothic16Neon-Regular.ttf" ] || { python3 -I "$R/make-fonts.py" "$F"; fc-cache "$F"; }

# Everything of the graphs' face but its panel view, which comes from home/
cp -r --update=none /usr/share/ksysguard/sensorfaces/org.kde.ksysguard.horizontalbars/contents \
    "$HOME/.local/share/ksysguard/sensorfaces/org.holman.neonbars/"

# Icons: the repo's Zafiro; build-theme.py makes Zafiro-Red on top of it
if [ ! -d "$HOME/.local/share/icons/Zafiro" ]; then
    mkdir -p "$HOME/.local/share/icons"
    tar -C "$HOME/.local/share/icons" --zstd -xf "$R/../extras/icons/Zafiro.tar.zst"
fi

# Square GTK: after KDE's import, in the files KDE keeps rewriting that line in
for g in gtk-3.0 gtk-4.0; do
    grep -qs neon-ninja "$HOME/.config/$g/gtk.css" || cat "$R/gtk-square.css" >> "$HOME/.config/$g/gtk.css"
done

# Spotify: the repo's text theme in these colors. It needs a new start of Spotify to show.
if command -v spicetify >/dev/null; then
    remember .config/spicetify/Themes/text/user.css
    sed 's/--font-family: "JetBrains Mono", monospace/--font-family: "Moralerspace Neon", monospace/' \
        "$R/../extras/spicetify/text/user.css" > "$HOME/.config/spicetify/Themes/text/user.css"
    spicetify config current_theme text color_scheme NeonNinja >/dev/null
    spicetify apply -q -n >/dev/null 2>&1 || echo "spicetify apply failed; run it by hand"
fi

# Today's desktop, once: the theme to go back to
[ -d "$HOME/.local/share/plasma/look-and-feel/org.holman.tokyored" ] || python3 -I "$R/build-theme.py" capture
python3 -I "$R/build-theme.py" neonninja

# Tiling is off until Meta+Shift+T; this only makes its shortcuts exist
kwriteconfig6 --file kwinrc --group Plugins --key tilingEnabled true
qdbus6 org.kde.KWin /KWin reconfigure

shortcut() {  # desktop file, name, Qt key code. New ones only: a key already taken is left alone and reported.
    a="['$1','_launch','$2','Launch $2']"
    [ -z "$(kreadconfig6 --file kglobalshortcutsrc --group services --group "$1" --key _launch)" ] || return 0
    if [ "$(qdbus6 org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel.isGlobalShortcutAvailable "$3" "$1")" = true ]; then
        gdbus call --session -d org.kde.kglobalaccel -o /kglobalaccel -m org.kde.KGlobalAccel.doRegister "$a" >/dev/null
        gdbus call --session -d org.kde.kglobalaccel -o /kglobalaccel -m org.kde.KGlobalAccel.setForeignShortcut "$a" "[$3]" >/dev/null
    else
        echo "shortcut for $1 is taken, skipped"
    fi
}
SHIFT=$((0x02000000)) CTRL=$((0x04000000)) ALT=$((0x08000000))
shortcut org.kde.plasma-systemmonitor.desktop "System Monitor" $((CTRL + SHIFT + 0x01000000))  # Ctrl+Shift+Esc

# Ctrl+Alt+T keeps its key and opens the active theme's terminal
if [ "$(kreadconfig6 --file kglobalshortcutsrc --group services --group theme-terminal.desktop --key _launch)" = "" ]; then
    gdbus call --session -d org.kde.kglobalaccel -o /kglobalaccel -m org.kde.KGlobalAccel.setForeignShortcut "['Alacritty.desktop','_launch','Alacritty','Launch Alacritty']" "@ai []" >/dev/null
    shortcut theme-terminal.desktop Terminal $((CTRL + ALT + 0x54))
fi

plasma-apply-lookandfeel -a org.holman.neonninja --resetLayout
# The layout script writes the font silently a moment later, so the GTK sync misses it until the next login.
# A changed value with --notify tells it now; a write of the same value would not count as a change.
sleep 5
font=$(kreadconfig6 --file kdeglobals --group General --key font)
kwriteconfig6 --file kdeglobals --group General --key font "$font,"
kwriteconfig6 --notify --file kdeglobals --group General --key font "$font"
# KWin reloaded while the theme was being applied, before that script wrote the window buttons
qdbus6 org.kde.KWin /KWin reconfigure
# The animation for windows moved by tiling starts with KWin from now on; this is for the running session
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect kwin4_effect_geometry_change >/dev/null || true

echo "installed. Going back at any time: plasma-apply-lookandfeel -a org.holman.tokyored --resetLayout"
