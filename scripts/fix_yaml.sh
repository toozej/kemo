#!/bin/bash
set -e
find demos -type f -name "*.yaml" | while read -r file; do
  echo "Fixing $file"
  # Add document start if it's missing
  if ! grep -q -- '---' "$file"; then
    (echo "---"; cat "$file") > "$file.tmp" && mv "$file.tmp" "$file"
  fi
  # Re-format with yq
  yq e '.' -i "$file"
done
