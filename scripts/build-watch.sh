#!/usr/bin/env bash
# Builds a personal copy of the app with your LIFX token and light filters
# built in, and optionally copies it onto a USB-connected watch.
#
# Sideloaded apps can't get settings from the Garmin Connect phone app, so
# the token and filters are written into a temporary copy of the project as
# default setting values. Nothing private is written into the repo itself.
#
#   scripts/build-watch.sh            build bin/personal/LIFX.prg
#   scripts/build-watch.sh --install  build, then copy it to the watch
#   scripts/build-watch.sh --list     list your lights (to pick filter names)
#
# Reads ~/.config/lifx/token and ~/.config/lifx/watch-settings
# (override the folder with LIFX_CONFIG_DIR).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="${LIFX_CONFIG_DIR:-$HOME/.config/lifx}"
TOKEN_FILE="$CONFIG_DIR/token"
SETTINGS_FILE="$CONFIG_DIR/watch-settings"
DEV_KEY="${GARMIN_DEV_KEY:-$HOME/.Garmin/keys/developer_key.der}"
OUTPUT="$REPO_DIR/bin/personal/LIFX.prg"

die() { echo "error: $*" >&2; exit 1; }

MODE=build
case "${1:-}" in
    "") ;;
    --install) MODE=install ;;
    --list) MODE=list ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option '$1' (try --help)" ;;
esac

[ -s "$TOKEN_FILE" ] || die "no LIFX token in $TOKEN_FILE"
TOKEN="$(tr -d '[:space:]' < "$TOKEN_FILE")"

if [ "$MODE" = list ]; then
    curl -sf -H "Authorization: Bearer $TOKEN" https://api.lifx.com/v1/lights/all \
        | python3 -I -c '
import json, sys
for l in json.load(sys.stdin):
    state = "" if l["connected"] else "  (offline)"
    print(l["location"]["name"] + "/" + l["group"]["name"] + ": " + l["label"] + state)
' || die "couldn't fetch lights from LIFX (check the token)"
    exit 0
fi

HIDE_LIGHTS="" SHOW_LIGHTS="" DEVICE="fr265"
if [ -f "$SETTINGS_FILE" ]; then
    # shellcheck source=/dev/null
    source "$SETTINGS_FILE"
fi

# Toolchain: SDK from the SDK Manager's current-sdk.cfg (else the newest
# installed), Java from PATH or ~/.local/opt.
SDK_ROOT="$HOME/.Garmin/ConnectIQ"
SDK_DIR=""
[ -f "$SDK_ROOT/current-sdk.cfg" ] && SDK_DIR="$(tr -d '\n' < "$SDK_ROOT/current-sdk.cfg")"
[ -x "$SDK_DIR/bin/monkeyc" ] || SDK_DIR="$(ls -d "$SDK_ROOT"/Sdks/*/ 2>/dev/null | sort -V | tail -1)"
MONKEYC="${SDK_DIR%/}/bin/monkeyc"
[ -x "$MONKEYC" ] || die "Connect IQ SDK not found under $SDK_ROOT/Sdks"
if ! command -v java >/dev/null; then
    JDK="$(ls -d "$HOME"/.local/opt/jdk-* 2>/dev/null | sort -V | tail -1)"
    [ -n "$JDK" ] || die "java not found (install a JDK, or put one in ~/.local/opt)"
    export JAVA_HOME="$JDK" PATH="$JDK/bin:$PATH"
fi
[ -f "$DEV_KEY" ] || die "developer key not found at $DEV_KEY"
[ -d "$SDK_ROOT/Devices/$DEVICE" ] || die "device files for '$DEVICE' missing; download them in the SDK Manager"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp -r "$REPO_DIR"/{manifest.xml,monkey.jungle,source,resources} "$WORK/"

python3 -I - "$WORK/resources/settings/properties.xml" "$TOKEN" "$HIDE_LIGHTS" "$SHOW_LIGHTS" <<'EOF'
import sys
from xml.sax.saxutils import escape
path, token, hide, show = sys.argv[1:]
text = open(path).read()
for prop, value in (("LIFX_API_KEY", token), ("HIDE_LIGHTS", hide), ("SHOW_LIGHTS", show)):
    empty = f'<property id="{prop}" type="string"></property>'
    if empty not in text:
        sys.exit(f"error: {prop} not found (empty) in properties.xml")
    text = text.replace(empty, f'<property id="{prop}" type="string">{escape(value)}</property>')
open(path, "w").write(text)
EOF

echo "Building for $DEVICE  (hide: '${HIDE_LIGHTS}'  show: '${SHOW_LIGHTS}')"
mkdir -p "$(dirname "$OUTPUT")"
if ! "$MONKEYC" -d "$DEVICE" -f "$WORK/monkey.jungle" -o "$OUTPUT" -y "$DEV_KEY" > "$WORK/build.log" 2>&1; then
    grep -E "ERROR" "$WORK/build.log" >&2 || cat "$WORK/build.log" >&2
    die "build failed"
fi
echo "Built $OUTPUT"
echo "Keep it private: your LIFX token is inside it."

[ "$MODE" = install ] || exit 0

MOUNT="$(gio mount -l 2>/dev/null | grep -o 'mtp://091e_[^/ ]*' | head -1 || true)"
[ -n "$MOUNT" ] || die "no Garmin watch found; plug it in over USB and try again"
APPS="$MOUNT/Internal Storage/GARMIN/Apps"
gio remove "$APPS/LIFX.prg" 2>/dev/null || true
gio copy "$OUTPUT" "$APPS/LIFX.prg"
# The watch keeps the app's last settings in LIFX.SET, and those override the
# new built-in defaults, so remove it to make filter changes take effect.
gio remove "$APPS/SETTINGS/LIFX.SET" 2>/dev/null || true
echo "Copied to the watch. Eject and unplug it to finish installing."
