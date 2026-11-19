# Neon Ninja for KDE

The look and functions of this repo's XFCE desktop, made for Plasma 6 on Wayland: square, minimal, black and neon red. It lives in a global theme, so going back is changing the theme.

Made for NITROCACHY (CachyOS, Plasma 6.8, NVIDIA, 2560x1440). The repo's root `install.sh` is for the Dell: never run it here.

## Use

| To | Run |
|---|---|
| Install packages (once, asks for the password) | `pkexec bash "$PWD/kde/install-packages.sh"` (pkexec changes directory: the path must be absolute) |
| Install and apply | `sh kde/install.sh` |
| Go to Neon Ninja | `plasma-apply-lookandfeel -a org.holman.neonninja --resetLayout` |
| Go back to today's desktop | `plasma-apply-lookandfeel -a org.holman.tokyored --resetLayout` |
| See what differs from the saved desktop | `neon-ninja-remove --check` |
| Remove everything (logs out) | `neon-ninja-remove` |
| Then, packages and the saved copy | `neon-ninja-remove --packages`, `neon-ninja-remove --purge` |

In System Settings, a theme change needs "Desktop and window layout" ticked. If a session breaks, run `neon-ninja-remove --restore-now` from a TTY (Ctrl+Alt+F3) and reboot.

## What follows the theme

| Behavior | What |
|---|---|
| Changes with the theme | Colors, Plasma style, window decoration, Qt style, icons, fonts, Alt+Tab, bar, dock, graphs, clock, splash, animations, default terminal, KRunner settings |
| Only exists inside the Neon kitty | Prompt, btop, fzf and bat colors. Alacritty and `kitty.conf` are not edited |
| Stays until `neon-ninja-remove` | Square GTK rules, Spotify theme |
| Installed, no effect until used | Tiling (off at login), new shortcuts, packages (`cava`, `yazi`, `tty-clock`, `cmatrix`) |

## Shortcuts

Nothing existing was rebound. The only move is Ctrl+Alt+T: same key, now it opens the active theme's terminal.

| Key | Action |
|---|---|
| Meta+Shift+T | Tiling on or off, for this desktop |
| Meta+Ctrl+H/J/K/L | Focus left, down, up, right |
| Meta+Ctrl+Shift+H/J/K/L | Swap with that neighbor |
| Meta+Ctrl+Return | Make the active window the main one |
| Meta+Ctrl+Alt+arrows | Move the window's edge 40 px; outside tiling, up maximizes |
| Ctrl+Shift+Esc | System Monitor |

Tiling is a golden spiral with 2 px gaps and no title bars. Dropping a window on another swaps them, and resizing one moves its neighbors. Dialogs, fullscreen, maximized and all-desktops windows stay out.

## Fonts

Plasma and Qt size rows and popups from the font's line height, and M PLUS 1's is 1.448 lines against the usual 1.2: that made everything look too tall. DotGothic16's dots only land on whole pixels at exactly 16 px without antialiasing. So `make-fonts.py` writes `M PLUS 1 Neon` and `DotGothic16 Neon`, renamed copies with corrected line metrics (the glyphs are untouched), `60-neon-ninja.conf` turns off antialiasing for the second one, and the clock is always 16 px. The bar's meters use M PLUS 1 Neon, which stays legible at 11 px.

That last part is why the clock is `org.holman.neonclock` and not the stock one, which fits its font to the panel's height and blurs it. Compared with the stock clock it has no settings, no timezones and no holidays in the calendar. A click opens the calendar as usual.

## Changing one thing

| What | Where | Then |
|---|---|---|
| Icons, bar height, fonts, graphs, Alt+Tab | `ICONS`, `BAR`, `FONT`, `stats()` and the defaults in `build-theme.py` | `sh kde/install.sh` |
| Bars with their labels | `home/.local/share/ksysguard/sensorfaces/org.holman.neonbars` | `sh kde/install.sh` |
| Clock format | `home/.local/share/plasma/plasmoids/org.holman.neonclock` | `sh kde/install.sh` |
| Splash | `splash/Splash.qml` | `sh kde/install.sh`; try it with `ksplashqml org.holman.neonninja --test --window` |
| Title bar buttons | `ButtonSize` in `home/.config/darklyrc` | `sh kde/install.sh` |
| Terminal opacity | `background_opacity` in `home/.config/kitty/neon-ninja.conf` | `sh kde/install.sh` |
| Plasma style, and the 22 px of everything in the bar | `make-square-theme.py`: `tb=30` in `panel-background` (Plasma clamps it to 22 px of content), `TASK_ICON_MARGIN` for the windows, which fill the bar | Run it, then `sh kde/install.sh` |

## Known limits

- `--resetLayout` drops desktops of screens that are not connected, like a virtual tablet, and a theme cannot set their wallpaper. Set it with a right click until the next theme change; `neon-ninja-remove` restores it.
- Going to Tokyo Red in a running session does not bring Magic Lamp back until the next login. Without logging out: `qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect magiclamp`. Geometry Change stays on the same way, until the next login or `unloadEffect kwin4_effect_geometry_change`.
- After a plain theme change, GTK apps keep the previous font until the next login.
- libadwaita apps (here zenity and faugus-launcher) are square but keep their own gray. Apps that draw their own title bar (Brave, Discord, VS Code) do not follow any of this.
- Icons sent by an app as an image, like `ai-tray`, stay in color.
- Icons: `icons/zafiro-extra.tar.zst` holds the upstream Zafiro icons (zayronxio/Zafiro-icons, GPL-3.0, Dark at 5c7f38c) the repo's copy lacks; remake it with `build-theme.py zafiro-extra DIR`. `Zafiro-Red-Lines` adds Breeze's one-color icons as a fallback. A theme's name is shortened at its dashes before the next theme is tried, so an icon added to Zafiro-Red can replace Zafiro's: `zafiro-extra` leaves those out. Measure icon sources in the session's environment: with `QT_QPA_PLATFORM=offscreen`, `kiconfinder6` also searches `breeze`, which a real session does not. Office documents use each program's color instead of Zafiro's muted fills (`office` in `zafiro_red()`). `APP_ICONS` in `build-theme.py` gives apps the Zafiro icon they have under another name.
- After a plain theme change KWin keeps the previous window buttons until `qdbus6 org.kde.KWin /KWin reconfigure` or the next login, because it reloads before the theme writes them. `install.sh` already does this.
- Geometry Change animates tiling and moved windows. It comes from the AUR and is plain JavaScript: if a Plasma update breaks it, it just stops animating.
- Darkly is compiled: after some Plasma or Qt updates it may ask for a rebuild (`paru -S darkly`). Until then windows fall back to the default decoration.
- Spotify's theme shows after restarting Spotify.

## Checks

- `sh kde/test-roundtrip.sh`: install, change and restore in a throwaway HOME.
- `node kde/home/.local/share/kwin/scripts/tiling/contents/code/main.js`: the spiral's geometry.
