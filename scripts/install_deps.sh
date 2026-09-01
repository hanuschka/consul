#!/usr/bin/env bash
#
# Installs the external dependencies the app reports on in the internal API
# stats endpoint, under features.ai:
#
#   import      pandoc, poppler-utils, imagemagick   (projekt_import_tools)
#   chrome      shared libraries headless Chrome needs to start
#               (headless_browser_libraries) -- without these the evaluation
#               PDF export fails with renderer_unavailable
#   marking     exiftool (image_ai_marking) -- AI image generation fails
#               outright without it, because a generated picture that cannot
#               be marked as AI-generated is not attached at all
#
# Run with no arguments to install everything, or name the groups to install:
#
#   scripts/install_deps.sh
#   scripts/install_deps.sh marking
#   scripts/install_deps.sh import chrome
#
# Ubuntu/Debian and macOS. Safe to re-run: every step skips work already done.
#
# Deliberately not installed: jemalloc. The allocator shows up in the stats
# report too, but swapping it in needs a systemd drop-in that capistrano
# regenerates on each deploy, so installing the library alone would report a
# change that has not actually taken effect.

set -euo pipefail

# Sonames rather than package names, because this is what the app itself looks
# for when it decides whether Chrome can start.
readonly CHROME_SONAMES=(
  libnss3.so libnssutil3.so libsmime3.so libnspr4.so
  libatk-1.0.so.0 libatk-bridge-2.0.so.0
  libXcomposite.so.1 libXdamage.so.1 libXfixes.so.3 libXrandr.so.2
  libgbm.so.1 libasound.so.2 libatspi.so.0
)

OS=""
SUDO=""

log()  { printf '\033[1m==>\033[0m %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

detect_os() {
  case "$(uname -s)" in
    Linux)  OS="linux" ;;
    Darwin) OS="macos" ;;
    *)      die "unsupported operating system: $(uname -s)" ;;
  esac

  if [ "$OS" = "linux" ]; then
    command -v apt-get >/dev/null 2>&1 ||
      die "this script supports apt-based distributions only"

    # Already root in a container or a provisioning run; sudo may not exist.
    if [ "$(id -u)" -ne 0 ]; then
      command -v sudo >/dev/null 2>&1 || die "sudo is required but not installed"
      SUDO="sudo"
    fi
  else
    command -v brew >/dev/null 2>&1 ||
      die "Homebrew is required: https://brew.sh"
  fi
}

apt_update_once() {
  if [ -n "${APT_UPDATED:-}" ]; then
    return
  fi

  log "Refreshing apt package lists"
  $SUDO apt-get update -qq
  APT_UPDATED=1
}

apt_install() {
  apt_update_once
  $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

# Ubuntu 24.04 renamed several libraries with a t64 suffix for the 64-bit
# time_t transition. Resolving the name against the local package index keeps
# one script working on both 22.04 and 24.04.
apt_resolve() {
  local preferred=$1 fallback=$2

  if apt-cache show "$preferred" >/dev/null 2>&1; then
    printf '%s' "$preferred"
  else
    printf '%s' "$fallback"
  fi
}

brew_install() {
  local formula
  for formula in "$@"; do
    if brew list --formula "$formula" >/dev/null 2>&1; then
      info "$formula already installed"
    else
      log "Installing $formula"
      brew install "$formula"
    fi
  done
}

install_import_tools() {
  log "Projekt import tools (pandoc, poppler, imagemagick)"

  if [ "$OS" = "macos" ]; then
    brew_install pandoc poppler imagemagick
    return
  fi

  apt_install pandoc poppler-utils imagemagick
}

install_chrome_libraries() {
  log "Headless Chrome shared libraries"

  if [ "$OS" = "macos" ]; then
    info "not applicable on macOS -- Chrome bundles its own frameworks"
    return
  fi

  local packages=(
    libnss3 libnspr4 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1
  )

  packages+=("$(apt_resolve libatk1.0-0t64 libatk1.0-0)")
  packages+=("$(apt_resolve libatk-bridge2.0-0t64 libatk-bridge2.0-0)")
  packages+=("$(apt_resolve libasound2t64 libasound2)")
  packages+=("$(apt_resolve libatspi2.0-0t64 libatspi2.0-0)")

  apt_install "${packages[@]}"
}

# A prefix under /opt needs root; one in a home directory does not.
install_ai_marking() {
  log "AI image marking (exiftool)"

  if [ "$OS" = "macos" ]; then
    brew_install exiftool
    return
  fi

  apt_install libimage-exiftool-perl
}

check_command() {
  local label=$1
  shift

  local candidate
  for candidate in "$@"; do
    if command -v "$candidate" >/dev/null 2>&1; then
      printf '  ok       %s\n' "$label"
      return
    fi
  done

  printf '  MISSING  %s\n' "$label"
}

check_chrome_libraries() {
  if [ "$OS" = "macos" ]; then
    printf '  skipped  headless Chrome libraries (not used on macOS)\n'
    return
  fi

  local available missing=() soname
  available="$(ldconfig -p 2>/dev/null || true)"

  for soname in "${CHROME_SONAMES[@]}"; do
    case "$available" in
      *"$soname"*) ;;
      *) missing+=("$soname") ;;
    esac
  done

  if [ ${#missing[@]} -eq 0 ]; then
    printf '  ok       headless Chrome libraries (%d)\n' "${#CHROME_SONAMES[@]}"
  else
    printf '  MISSING  headless Chrome libraries: %s\n' "${missing[*]}"
  fi
}

verify() {
  log "Verification"

  check_command "pandoc" pandoc
  check_command "pdftotext (poppler)" pdftotext
  check_command "pdfimages (poppler)" pdfimages
  check_command "imagemagick" magick convert
  check_chrome_libraries
  check_command "exiftool" exiftool

  printf '\n'
  info "The app reports the same checks under features.ai in the internal"
  info "API stats endpoint. On a server, export EXIFTOOL_PATH only if the"
  info "binary lives somewhere outside PATH."
}

usage() {
  cat <<'USAGE'
Usage: scripts/install_deps.sh [group...]

Groups:
  import      pandoc, poppler, imagemagick
  chrome      headless Chrome shared libraries (Linux only)
  marking     exiftool, used to mark generated images as AI-generated
  verify      report what is installed without changing anything

With no group, installs all three and then verifies.
USAGE
}

main() {
  local groups=("$@")

  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
  esac

  detect_os

  if [ ${#groups[@]} -eq 0 ]; then
    groups=(import chrome marking verify)
  fi

  local group
  for group in "${groups[@]}"; do
    case "$group" in
      import)    install_import_tools ;;
      chrome)    install_chrome_libraries ;;
      marking)   install_ai_marking ;;
      verify)    verify ;;
      *)         usage; die "unknown group: $group" ;;
    esac
  done

  log "Done"
}

main "$@"
