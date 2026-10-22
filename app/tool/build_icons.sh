#!/usr/bin/env bash
# Renders the launcher icons in android/app/src/main/res from branding/*.svg.
# Needs rsvg-convert (librsvg).
set -euo pipefail

APP="$(cd "$(dirname "$0")/.." && pwd)"
RES="$APP/android/app/src/main/res"
BACKGROUND="#0F1012"

# density: legacy icon size (48dp), adaptive layer size (108dp)
for spec in mdpi:48:108 hdpi:72:162 xhdpi:96:216 xxhdpi:144:324 xxxhdpi:192:432; do
  IFS=: read -r density legacy layer <<< "$spec"
  dir="$RES/mipmap-$density"
  mkdir -p "$dir"
  rsvg-convert -w "$legacy" -h "$legacy" "$APP/branding/legacy.svg" -o "$dir/ic_launcher.png"
  rsvg-convert -w "$layer" -h "$layer" "$APP/branding/foreground.svg" \
    -o "$dir/ic_launcher_foreground.png"
done

# Android 8+: adaptive icon; Android 13+ also tints the monochrome layer to
# match the user's themed icons.
mkdir -p "$RES/mipmap-anydpi-v26"
cat > "$RES/mipmap-anydpi-v26/ic_launcher.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
XML
cat > "$RES/values/ic_launcher_background.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">$BACKGROUND</color>
</resources>
XML
