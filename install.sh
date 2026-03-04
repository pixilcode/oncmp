#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <bin_dir>"
  echo "  bin_dir  e.g. ~/.local/bin/"
  echo ""
  echo "Optional: BIN_INSTALL_NAME names the binary (default: oncmp)"
  exit 1
}

[[ $# -eq 1 ]] || usage

bin_dir="${1/#\~/$HOME}"
install_name="${BIN_INSTALL_NAME:-oncmp}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

echo "Building oncmp..."
gleam build

echo "Running gleescript..."
gleam run -m gleescript

echo "Moving ./oncmp to $bin_dir/$install_name"
mkdir -p "$bin_dir"
mv ./oncmp "$bin_dir/$install_name"

echo "Done. Ensure $bin_dir is in your PATH."
