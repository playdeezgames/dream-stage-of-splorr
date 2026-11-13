#!/usr/bin/env bash
# Renders real frames natively (the frame-dump tests in src/game/dump_test.odin) into
# assets/screenshots/01-play.png, 02-clear.png, 03-shop.png, 04-end.png (the 384x216 screen, 3x).
# Needs Pillow. Run: tools/make_shots.sh
set -euo pipefail
cd "$(dirname "$0")/.."
D="$(mktemp -d)"
odin test src/game -collection:tggd=src -define:ODIN_TEST_THREADS=1 \
	-define:DUMP_PLAY="$D/play.ppm" -define:DUMP_CLEAR="$D/clear.ppm" -define:DUMP_SHOP="$D/shop.ppm" -define:DUMP_END="$D/end.ppm" \
	-define:ODIN_TEST_NAMES=game.dump_play,game.dump_clear,game.dump_shop,game.dump_end >/dev/null 2>&1
python3 -I - "$D" <<'PY'
import os, sys
from PIL import Image
d = sys.argv[1]
for src, dst in [("play", "01-play"), ("clear", "02-clear"), ("shop", "03-shop"), ("end", "04-end")]:
    Image.open(os.path.join(d, src + ".ppm")).resize((384 * 3, 216 * 3), Image.NEAREST).save("assets/screenshots/%s.png" % dst)
print("assets/screenshots/01-play.png 02-clear.png 03-shop.png 04-end.png")
PY
rm -rf "$D"
