#!/usr/bin/env bash
# Builds assets/words/english.txt, the word list behind "sounds like"
# suggestions, from SCOWL (http://wordlist.aspell.net, permissive license).
# Each line is "<word> <level>": the SCOWL size level the word first appears
# in, 10 for the most common words up to 40.
set -euo pipefail

VERSION=2020.12.07
SHA256=5587667caa20c4891390c2d42dbb4d5c4c3f41bee77af1457ece3ba23fb859cc
APP="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

curl -fsSL -o "$WORK/scowl.tar.gz" \
  "https://downloads.sourceforge.net/wordlist/scowl-$VERSION.tar.gz"
echo "$SHA256  $WORK/scowl.tar.gz" | sha256sum -c --quiet
tar xzf "$WORK/scowl.tar.gz" -C "$WORK"
FINAL="$WORK/scowl-$VERSION/final"

mkdir -p "$APP/assets/words"
for level in 10 20 35 40; do
  {
    # Possessives ("cask's") only crowd out real suggestions; the common "'s"
    # contractions are kept.
    iconv -f latin1 -t utf-8 "$FINAL"/{english,american}-words."$level" \
      | grep -v -E "'s$" || true
    if [[ $level == 10 ]]; then
      printf '%s\n' "that's" "it's" "he's" "she's" "what's" "where's" "who's" \
        "there's" "here's" "let's" "how's" "when's" "why's"
    fi
    # Not every level has a contractions file ("that's", "don't").
    for list in "$FINAL"/{english,american}-contractions."$level"; do
      if [[ -f "$list" ]]; then iconv -f latin1 -t utf-8 "$list"; fi
    done
  } | grep -E "^[a-z']+$" | sed "s/\$/ $level/"
done | sort -k1,1 -u -s | sort -k2,2n -k1,1 > "$APP/assets/words/english.txt"
cp "$WORK/scowl-$VERSION/Copyright" "$APP/assets/words/SCOWL-LICENSE.txt"
wc -l < "$APP/assets/words/english.txt"
