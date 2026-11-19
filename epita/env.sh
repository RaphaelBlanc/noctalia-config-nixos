# shellcheck shell=bash
# Environnement commun à nc-start et nc-zsh (bash).
export NC_FLAKE_DIR="${NC_FLAKE_DIR:-$HOME/afs/.confs/noctalia-config-nixos}"
NC_FLAKE_DIR="$(realpath "$NC_FLAKE_DIR")"
nc_runtime_base="${XDG_RUNTIME_DIR:-/tmp/nc-epita-$(id -u)}"
mkdir -p "$nc_runtime_base"
if [ ! -O "$nc_runtime_base" ] || [ -L "$nc_runtime_base" ]; then
  echo "Répertoire utilisateur non sûr : $nc_runtime_base" >&2
  return 1
fi
chmod 700 "$nc_runtime_base"
export NC_RUNTIME_DIR="$nc_runtime_base/nc-epita"
mkdir -p "$NC_RUNTIME_DIR"
if [ ! -O "$NC_RUNTIME_DIR" ] || [ -L "$NC_RUNTIME_DIR" ]; then
  echo "Répertoire de session non sûr : $NC_RUNTIME_DIR" >&2
  return 1
fi
chmod 700 "$NC_RUNTIME_DIR"
export NC_ENV_LINK="$NC_RUNTIME_DIR/env"
export NC_SOURCE_LINK="$NC_RUNTIME_DIR/source"
export NC_ZSH_LINK="$NC_RUNTIME_DIR/zsh-custom"
export PATH="$HOME/.local/bin:$NC_ENV_LINK/bin:$HOME/afs/bin:$PATH"
export XDG_DATA_DIRS="$NC_ENV_LINK/share:${XDG_DATA_DIRS:-/run/current-system/sw/share}"
export ZSH="$NC_ENV_LINK/share/oh-my-zsh"
export ZSH_CUSTOM="$NC_ZSH_LINK"
