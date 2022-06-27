#!/bin/bash
#PBS -e /dev/null
#PBS -o /dev/null
set -euo pipefail
IFS=$'\n\t'

function frames_range() {
  (
    set +u
    echo "$FRAMES_RANGE" | perl -pe 's[.+/][]'
  )
}

module load blender
(
  cd "$OUTPUT_DIR"

  env | grep -P '^[A-Z]' | sort

  blender \
    -b "$BLEND_FILE_PATH" \
    -F PNG \
    -o "$OUTPUT_DIR/render_" \
    -x 1 \
    -t 0 \
    -E CYCLES \
    -f "$(frames_range)"
)