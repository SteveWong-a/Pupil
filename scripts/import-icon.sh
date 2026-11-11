#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INPUT_PNG="${1:-${PROJECT_DIR}/Resources/AppIcon.png}"

if [[ ! -f "${INPUT_PNG}" ]]; then
    echo "Error: Input PNG file not found at '${INPUT_PNG}'"
    echo "Usage: $0 [path/to/icon.png]"
    exit 1
fi

echo "==> Processing '${INPUT_PNG}' into AppIcon.icns..."

ICONSET_DIR="$(mktemp -d /tmp/PupilIconset-XXXXXX)"
trap 'rm -rf "${ICONSET_DIR}"' EXIT

python3 - <<EOF
import os
import subprocess
from PIL import Image
import numpy as np

src_path = "${INPUT_PNG}"
im = Image.open(src_path).convert("RGBA")

# Measure opaque bounds to determine padding
arr = np.array(im)
mask255 = arr[:, :, 3] > 200
if np.any(mask255):
    y_idx, x_idx = np.where(mask255)
    opaque_w = x_idx.max() - x_idx.min() + 1
    opaque_h = y_idx.max() - y_idx.min() + 1
    min_x, min_y = x_idx.min(), y_idx.min()
else:
    opaque_w, opaque_h = im.width, im.height
    min_x, min_y = 0, 0

# Target 824x824 squircle body in a 1024x1024 canvas (Apple HIG standard)
target_body_size = 824.0
scale = target_body_size / max(opaque_w, opaque_h)

new_w = max(1, int(round(im.width * scale)))
new_h = max(1, int(round(im.height * scale)))
resized = im.resize((new_w, new_h), Image.Resampling.LANCZOS)

canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
pos_x = int(round(100 - min_x * scale))
pos_y = int(round(100 - min_y * scale))

canvas.paste(resized, (pos_x, pos_y), resized)

iconset_path = "${ICONSET_DIR}/Pupil.iconset"
os.makedirs(iconset_path, exist_ok=True)

scales = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for px, name in scales:
    s_img = canvas.resize((px, px), Image.Resampling.LANCZOS)
    s_img.save(os.path.join(iconset_path, name))

out_icns = "${PROJECT_DIR}/Resources/AppIcon.icns"
subprocess.run(["iconutil", "-c", "icns", iconset_path, "-o", out_icns], check=True)
EOF

echo "==> Successfully updated: ${PROJECT_DIR}/Resources/AppIcon.icns"
