#!/usr/bin/env bash
# Downloads the pinned Whistle weights into the app's assets and verifies them.
set -euo pipefail

REVISION=741118687e1f008f06d1351a402a731274789790
SHA256=b6e02f048568ac5d01a2042556c658061e699acbc0aa2a1439f52f3d461dffeb
DEST="$(cd "$(dirname "$0")/.." && pwd)/assets/models/whistle.cact"

if [[ -f "$DEST" ]] && echo "$SHA256  $DEST" | sha256sum -c --status; then
  echo "whistle.cact already present"
  exit 0
fi

curl -fL --progress-bar -o "$DEST.part" \
  "https://huggingface.co/Cactus-Compute/whistle/resolve/$REVISION/whistle.cact"
echo "$SHA256  $DEST.part" | sha256sum -c
mv "$DEST.part" "$DEST"
