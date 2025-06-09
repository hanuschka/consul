#!/bin/bash

INPUT_DIR="."
OUTPUT_DIR="converted_pngs"
mkdir -p "$OUTPUT_DIR"

for svg in "$INPUT_DIR"/*.svg; do
    filename=$(basename "$svg" .svg)
    temp_png="$OUTPUT_DIR/${filename}_temp.png"
    final_png="$OUTPUT_DIR/${filename}.png"

    # 1. Convert SVG to PNG with transparent background
    inkscape "$svg" --export-type=png --export-background-opacity=0 --export-filename="$temp_png"

    # 2. Replace black (or dark) pixels with white while keeping transparency
    magick "$temp_png" \
        -fill white \
        -fuzz 20% \
        -opaque black \
        "$final_png"

    # 3. Clean up
    rm "$temp_png"

    echo "✔ Converted: $svg → $final_png"
done
