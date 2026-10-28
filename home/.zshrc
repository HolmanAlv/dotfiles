# ----------------------------------------
# Powerlevel10k Instant Prompt
# ----------------------------------------
# Esta sección mejora el tiempo de carga del prompt de Zsh (powerlevel10k).
# Debe mantenerse al principio del archivo.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ----------------------------------------
# Oh My Zsh Configuración principal
# ----------------------------------------
export ZSH="$HOME/.oh-my-zsh"  # Ruta a la instalación de Oh My Zsh

# Tema a usar. Powerlevel10k requiere Nerd Fonts para mostrarse correctamente.
ZSH_THEME="powerlevel10k/powerlevel10k"
POWERLEVEL10K_MODE="nerdfont-complete"

# ----------------------------------------
# Plugins
# ----------------------------------------
# Lista de plugins a cargar con Oh My Zsh.
# Evita cargar demasiados para no afectar el rendimiento.
plugins=(
  git                  # Funciones útiles para git
  zsh-autosuggestions  # Sugerencias automáticas mientras escribes
  zsh-syntax-highlighting
  sudo                 # Agrega "sudo" automáticamente al principio si un comando falla
)

# ----------------------------------------
# Cargar Oh My Zsh
# ----------------------------------------
source $ZSH/oh-my-zsh.sh

# ----------------------------------------
# Configuración del usuario
# ----------------------------------------

# FZF: Framework de búsqueda interactiva para usar con Ctrl+R, Ctrl+T, etc.
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Tema: fzf y bat usan los 16 colores ANSI de la terminal, así siguen al tema activo
export FZF_DEFAULT_OPTS='--color=16'
export BAT_THEME=ansi

# Powerlevel10k: paleta del tema activo (bin/theme) y luego la configuración del prompt
[[ -f ~/.config/theme/p10k.zsh ]] && source ~/.config/theme/p10k.zsh
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# PATH: incluye binarios locales para pipx, cargo, scripts, etc.
export PATH="$HOME/.local/bin:$PATH"

#alias
#alias mario='fceux Desktop/Super\ Mario\ Bros..nes > /dev/null 2>&1 &'
alias novedades='cd ~/Repos/pasantia/novedades_mf'
alias antigravity='agy'

# Levanta los servicios de desarrollo (desactivados al arranque para ahorrar bateria)
upservices() { sudo systemctl start docker postgresql mongodb }

# Baja los servicios de desarrollo (docker.socket primero, si no reactiva docker)
downservices() { sudo systemctl stop docker.socket docker postgresql mongodb }

# fnm
FNM_PATH="/home/holman/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --shell zsh)"
fi


# Added by Antigravity CLI installer
export PATH="/home/holman/.local/bin:$PATH"
