#!/bin/bash
# Adds the packages Neon Ninja needs: pkexec bash "$PWD/kde/install-packages.sh" (pkexec changes directory)
# What was not here before is listed for neon-ninja-remove --packages. Safe to repeat.
set -euo pipefail
exec > >(tee -a /var/log/neon-ninja-packages.log) 2>&1
echo "=== $(date -Is)"

N=$(id -un "${PKEXEC_UID:?run it with pkexec}")
H=$(getent passwd "$N" | cut -d: -f6)
L=$H/.local/share/neon-ninja/packages-added
as_user() { runuser -u "$N" -- env HOME="$H" "$@"; }

snapper -c root create -d "before neon-ninja packages"

REPO='kitty cava yazi tty-clock cmatrix python-fonttools'
AUR='darkly kwin-effects-geometry-change'

for p in $REPO $AUR; do
    pacman -Q "$p" >/dev/null 2>&1 || as_user sh -c "echo $p >> '$L'"
done
# shellcheck disable=SC2086
pacman -S --needed --noconfirm $REPO

aur() {
    B=$(as_user mktemp -d)
    as_user git clone --depth 1 "https://aur.archlinux.org/$1.git" "$B"
    (cd "$B" && as_user PKGDEST="$B" nice -n 15 makepkg --noconfirm)
    pacman -U --noconfirm "$B/$1"-*.pkg.tar.*
    rm -rf "$B"
}

# Darkly's build tools leave with the build unless they were already here
if ! pacman -Q darkly >/dev/null 2>&1; then
    tools=$(pacman -T cmake extra-cmake-modules || true)
    # shellcheck disable=SC2086
    [ -z "$tools" ] || pacman -S --needed --noconfirm --asdeps $tools
    aur darkly
    # shellcheck disable=SC2086
    [ -z "$tools" ] || pacman -Rns --noconfirm $tools
fi

pacman -Q kwin-effects-geometry-change >/dev/null 2>&1 || aur kwin-effects-geometry-change

# shellcheck disable=SC2086
pacman -Q $REPO $AUR
echo "added: $(tr '\n' ' ' < "$L" 2>/dev/null)"
