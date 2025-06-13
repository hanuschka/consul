#!/bin/bash

# Check if ImageMagick is installed
if ! command -v identify &> /dev/null || ! command -v convert &> /dev/null; then
  echo "ImageMagick is not installed. Install it with: brew install imagemagick"
  exit 1
fi

# Loop through all PNG files in the current directory
for file in ./*.png; do
  [ -e "$file" ] || continue

  # Get image width and height
  read width height < <(identify -format "%w %h" "$file")

  # Check if either dimension is greater than 50
  if [[ $width -gt 50 || $height -gt 50 ]]; then
    # Create new filename
    base="${file%.*}"
    ext="${file##*.}"
    newfile="${base}_50px.${ext}"

    # Resize to fit within 50x50 while preserving aspect ratio
    convert "$file" -resize 50x50 "$newfile"
    echo "Copied and resized: $file -> $newfile"
  fi
done

