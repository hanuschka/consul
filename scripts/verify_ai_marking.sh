#!/usr/bin/env bash
#
# Reports whether an image is marked as AI-generated, from a file or a URL:
#
#   scripts/verify_ai_marking.sh banner.jpg
#   scripts/verify_ai_marking.sh https://example.org/banner.jpg
#
# The marker is the IPTC DigitalSourceType field, which is a published
# vocabulary term rather than anything private to this app -- so a reader with
# nothing but exiftool, or one of the public Content Credentials verifiers, can
# reach the same answer. This script only spares them knowing which field to
# look at.
#
# It also reports the generator's own signed manifest, which this app removes
# from what it stores: writing our marker changes the bytes that manifest
# hashes over, and a broken signature reads as tampering. So the manifest is
# expected to be absent from anything this app serves, and the report is there
# for pictures that came from somewhere else.
#
# Exit status is the verdict, so this can gate a script:
#   0  marked as AI-generated
#   1  not marked
#   2  the image could not be read, or exiftool is unavailable

set -euo pipefail

readonly TRAINED_ALGORITHMIC_MEDIA="http://cv.iptc.org/newscodes/digitalsourcetype/trainedAlgorithmicMedia"

readonly OK=0
readonly UNMARKED=1
readonly UNUSABLE=2

DOWNLOAD=""

log() { printf '\033[1m==>\033[0m %s\n' "$*"; }
die() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit "$UNUSABLE"; }

cleanup() {
  if [ -n "$DOWNLOAD" ]; then
    rm -f "$DOWNLOAD"
  fi
}

trap cleanup EXIT

usage() {
  cat <<'USAGE'
usage: scripts/verify_ai_marking.sh <file|url>
USAGE
}

main() {
  case "${1:-}" in
    -h|--help) usage; exit "$OK" ;;
    "")        usage >&2; exit "$UNUSABLE" ;;
  esac

  command -v exiftool >/dev/null 2>&1 ||
    die "exiftool not installed. Run scripts/install_deps.sh marking"

  local target=$1
  local path

  case "$target" in
    http://*|https://*)
      log "Downloading ${target}"
      DOWNLOAD="$(mktemp "${TMPDIR:-/tmp}/verify_ai_marking.XXXXXX")"

      curl -fsSL --max-time 60 "$target" -o "$DOWNLOAD" ||
        die "could not download ${target}"

      path="$DOWNLOAD"
      ;;
    *)
      [ -f "$target" ] || die "no such file: ${target}"
      path="$target"
      ;;
  esac

  local tags
  tags="$(exiftool -a -G1 "$path" 2>/dev/null)" || die "exiftool could not read ${target}"

  # A URL answering with a sign-in or error page downloads as HTML under an
  # image file name, which otherwise reads as an unmarked picture.
  printf '%s' "$tags" | grep -q '^\[File\].*File Type' ||
    die "not a readable image -- a URL answering with a login or error page downloads as HTML"

  log "AI marking"

  printf '  dimensions   %s\n' \
    "$(printf '%s' "$tags" | grep -m1 'Image Size' | sed 's/.*: //' || true)"

  # Matched on the group tag rather than the field name: the generator's own
  # manifest carries a digital source type of its own, under [CBOR], and the
  # two say different things about the file -- ours survives a resize, the
  # manifest's does not.
  local field_source_type manifest_source_type
  field_source_type="$(printf '%s' "$tags" | grep -m1 '^\[XMP-iptcExt\].*Digital Source Type' | sed 's/.*: //' || true)"
  manifest_source_type="$(printf '%s' "$tags" | grep -m1 '^\[CBOR\].*Digital Source Type' | sed 's/.*: //' || true)"

  local status="$UNMARKED"

  if [ "$field_source_type" = "$TRAINED_ALGORITHMIC_MEDIA" ]; then
    printf '  IPTC field   YES (trainedAlgorithmicMedia)\n'
    status="$OK"
  elif [ -n "$field_source_type" ]; then
    printf '  IPTC field   NO (DigitalSourceType is %s)\n' "$field_source_type"
  else
    printf '  IPTC field   NO (absent)\n'
  fi

  log "Content Credentials"

  if printf '%s' "$tags" | grep -q 'JUMD Label *: c2pa$'; then
    printf '  manifest     PRESENT\n'
    printf '  generator    %s\n' \
      "$(printf '%s' "$tags" | grep -m1 'Claim Generator Info Name' | sed 's/.*: //' || true)"

    if [ "$manifest_source_type" = "$TRAINED_ALGORITHMIC_MEDIA" ]; then
      printf '  source type  trainedAlgorithmicMedia\n'
      status="$OK"
    fi
  else
    printf '  manifest     ABSENT (expected on anything this app serves)\n'
  fi

  return "$status"
}

main "$@"
