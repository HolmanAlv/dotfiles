#!/bin/sh
# Install, change things, restore, in a throwaway HOME: the files must come back exactly as they were.
set -eu
R=$(dirname "$(readlink -f "$0")")
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
H=$T/home

mkdir -p "$H/.config/kdedefaults" "$H/.config/gtk-3.0"
echo original > "$H/.config/kdeglobals"
echo original > "$H/.config/kdedefaults/kwinrc"
echo original > "$H/.config/gtk-3.0/gtk.css"
cp -a "$H" "$T/before"

HOME=$H NO_SESSION=1 sh "$R/install.sh"

# what a session does afterwards: edit a saved file, drop a new one in a saved folder, create a config that was absent
echo changed > "$H/.config/kdeglobals"
echo new > "$H/.config/kdedefaults/ksplashrc"
echo new > "$H/.config/krunnerrc"
mkdir -p "$H/.local/share/fonts/neon-ninja" && echo font > "$H/.local/share/fonts/neon-ninja/a.ttf"

# a second install must not save the changed files over the originals
HOME=$H NO_SESSION=1 sh "$R/install.sh"

HOME=$H sh "$R/neon-ninja-remove" --check | grep -q '[1-9][0-9]* difference' || { echo 'FAIL: --check saw no changes'; exit 1; }
HOME=$H NO_SESSION=1 sh "$R/neon-ninja-remove" --restore-now
HOME=$H sh "$R/neon-ninja-remove" --check | grep -q '^0 difference' || { echo 'FAIL: --check after restore'; exit 1; }

# the saved copy and the script live in .local until --purge; the generated files there are covered by --check above
diff -r --exclude=.local "$T/before" "$H" || { echo 'FAIL: files differ'; exit 1; }

HOME=$H sh "$R/neon-ninja-remove" --purge
[ ! -e "$H/.local/share/neon-ninja" ] || { echo 'FAIL: --purge left the backup'; exit 1; }
echo ok
