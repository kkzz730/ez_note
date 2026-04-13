#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MASTER="$ROOT/Resources/EzNote-icon-master.png"
ICNSET="$ROOT/Resources/EzNote.iconset"
OUT="$ROOT/Resources/AppIcon.icns"

if [[ ! -f "$MASTER" ]]; then
  echo "Missing $MASTER" >&2
  exit 1
fi

rm -rf "$ICNSET"
mkdir -p "$ICNSET"

while read -r name size; do
  sips -z "$size" "$size" "$MASTER" --out "$ICNSET/$name" >/dev/null
done <<'EOF'
icon_16x16.png 16
icon_16x16@2x.png 32
icon_32x32.png 32
icon_32x32@2x.png 64
icon_128x128.png 128
icon_128x128@2x.png 256
icon_256x256.png 256
icon_256x256@2x.png 512
icon_512x512.png 512
icon_512x512@2x.png 1024
EOF

iconutil -c icns "$ICNSET" -o "$OUT"
rm -rf "$ICNSET"
echo "✅ Wrote $OUT"
