# xfce_everforest_dotfiles

Arch + XFCE (X11) con Everforest Dark Hard, bordes cuadrados y temas intercambiables.

## Uso

```sh
./install.sh            # máquina nueva: paquetes, temas, enlaces, ajustes XFCE
./install.sh --no-pkgs  # sin pacman/yay
theme gruvbox           # cambiar de tema (en vivo)
theme everforest --system   # además el login (LightDM, pide sudo)
```

## Cómo está hecho

- `home/` es un espejo de `~`. `install.sh` enlaza cada fichero; lo que ya existía queda como `*.pre-dotfiles`.
- `~/.config/theme` es un enlace a `themes/<nombre>`. Alacritty, Rofi, p10k y Legcord importan sus colores desde ahí, así que sus configs no cambian nunca.
- `bin/theme` aplica el resto:
  - por xfconf: GTK, iconos, cursor y fondo;
  - por gsettings: libadwaita y Electron;
  - con un `sed` de una línea: btop, VS Code y Zed (no se enlazan porque reescriben su propia config);
  - además Plank y Spicetify.
- fzf, bat, micro, cava, htop, git y ls usan los 16 colores ANSI de la terminal: siguen al tema sin fichero propio.
- Tema GTK: [Colloid](https://github.com/vinceliuice/Colloid-gtk-theme) compilado con los radios a 0.
- Bordes de ventana: tema xfwm4 `Square` (basado en Metabox): cuadrado, contorno marcado y colores tomados del tema GTK.
- Apps Qt: `QT_QPA_PLATFORMTHEME=gtk3` en `.xprofile`, sin Kvantum. Hace falta volver a iniciar sesión.

## Añadir un tema

1. `cp -r themes/gruvbox themes/<nuevo>`.
2. Editar en esa carpeta:
   - `theme.env` (nombres de GTK, iconos, cursor, btop, VS Code, Zed y Spicetify);
   - `alacritty.toml`, `rofi.rasi`, `p10k.zsh`, `plank/dock.theme` y `legcord.css` (colores);
   - el fondo, en `walls/`.
3. Si Colloid tiene ese esquema (nord, dracula, catppuccin), compilarlo como en `install.sh`.

`theme` valida que existan el GTK, los iconos y el cursor antes de tocar nada.

## Manual (no se puede automatizar bien)

| App | Tema |
|---|---|
| Zen | [Everforest Dark Official](https://addons.mozilla.org/firefox/addon/everforest-dark-official/) (de sainnhe) |
| Brave | un tema Everforest de la Chrome Web Store |
| Obsidian | Ajustes → Apariencia → Temas → "Everforest Enchanted" |
| Zed | extensión "Everforest" (`zed: extensions`); Gruvbox ya viene incluido |
| Spotify | `sudo chmod a+wr /opt/spotify && sudo chmod -R a+wr /opt/spotify/Apps`, luego `spicetify backup apply` |
| Legcord | reiniciarlo para que cargue `quickCss.css` |

## No incluido

- GRUB: se queda el tema Hollow Knight.
- xfce4-terminal: la terminal por defecto es Alacritty.
- Configs huérfanas (hypr, waybar, wofi, mako, swaylock, starship): no se tocan.
