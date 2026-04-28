#!/usr/bin/env bash
set -e

NVIM_CONFIG="$HOME/.config/nvim"
TMP_DIR=$(mktemp -d)
SCRIPT="./setup-nvim.sh"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "=== Extracting config from $SCRIPT ==="

# Витягуємо файли зі скрипту в тимчасову директорію
current_file=""
current_tmp=""
in_heredoc=false

while IFS= read -r line; do
  # Визначаємо початок запису файлу
  if echo "$line" | grep -qP 'cat > "\$NVIM_CONFIG/'; then
    current_file=$(echo "$line" | grep -oP 'cat > "\$NVIM_CONFIG/\K[^"]+')
    current_tmp="$TMP_DIR/$current_file"
    mkdir -p "$(dirname "$current_tmp")"
    in_heredoc=true
    > "$current_tmp"
    continue
  fi

  # Кінець heredoc
  if $in_heredoc && [ "$line" = "EOF" ]; then
    in_heredoc=false
    current_file=""
    continue
  fi

  # Записуємо рядки heredoc
  if $in_heredoc && [ -n "$current_file" ]; then
    echo "$line" >> "$current_tmp"
  fi
done < "$SCRIPT"

echo ""
echo "=== Comparing files ==="

updated=0
for tmp_file in $(find "$TMP_DIR" -type f); do
  rel_path="${tmp_file#$TMP_DIR/}"
  real_file="$NVIM_CONFIG/$rel_path"

  if [ ! -f "$real_file" ]; then
    echo "Missing: $rel_path"
    mkdir -p "$(dirname "$real_file")"
    cp "$tmp_file" "$real_file"
    echo "  → Created"
    updated=$((updated + 1))
    continue
  fi

  tmp_md5=$(md5sum "$tmp_file" | cut -d' ' -f1)
  real_md5=$(md5sum "$real_file" | cut -d' ' -f1)

  if [ "$tmp_md5" != "$real_md5" ]; then
    echo "Changed: $rel_path"
    diff --color=always "$real_file" "$tmp_file" || true
    echo ""
    read -p "  Update $rel_path? [y/N] " answer
    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
      cp "$tmp_file" "$real_file"
      echo "  → Updated"
      updated=$((updated + 1))
    else
      echo "  → Skipped"
    fi
  else
    echo "✓ $rel_path"
  fi
done

echo ""
echo "=== Summary: $updated file(s) updated ==="
