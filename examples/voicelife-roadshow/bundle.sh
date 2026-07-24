#!/usr/bin/env bash
# Bundle html-ppt into a standalone HTML file with all CSS/JS inlined.
# Usage: bundle.sh <input.html> [output.html]

set -euo pipefail

INPUT="${1:-}"
if [[ -z "$INPUT" || ! -f "$INPUT" ]]; then
  echo "usage: bundle.sh <input.html> [output.html]" >&2
  exit 1
fi

OUTPUT="${2:-${INPUT%.*}-standalone.html}"
INPUT_DIR="$(cd "$(dirname "$INPUT")" && pwd)"
ASSETS_DIR="$(cd "$(dirname "$INPUT")/../../.claude/skills/html-ppt/assets" && pwd)"

inline() {
  local f="$1"
  if [[ ! -f "$f" ]]; then return 1; fi
  cat "$f"
}

# Copy input to output with inlined replacements
cp "$INPUT" "$OUTPUT"

# 1. Replace each <link rel="stylesheet" href="..."> with <style> content
while IFS= read -r href; do
  css_file="$INPUT_DIR/$href"
  # Resolve relative paths (../../.claude/...)
  if [[ ! -f "$css_file" ]]; then
    css_file="$(cd "$INPUT_DIR" && realpath "$href" 2>/dev/null || echo "")"
  fi
  # Try from assets dir
  if [[ ! -f "$css_file" ]]; then
    css_file="$ASSETS_DIR/${href##*/}"
  fi
  # Try from themes dir
  if [[ ! -f "$css_file" ]]; then
    css_file="$ASSETS_DIR/themes/${href##*/}"
  fi
  # Try from animations dir
  if [[ ! -f "$css_file" ]]; then
    css_file="$ASSETS_DIR/animations/${href##*/}"
  fi

  if [[ -f "$css_file" ]]; then
    content="$(inline "$css_file")"
    # Escape special characters for sed: \, &, /, newlines
    escaped_content="$(echo "$content" | sed 's/\\/\\\\/g' | sed 's/\//\\\//g' | sed 's/&/\\&/g' | tr '\n' '\f' | sed 's/\f/\\n/g')"
    # Remove the <link> tag and insert <style> after it (actually replace in-place)
    perl -i -pe "BEGIN{\$css=qq{$escaped_content}; \$css=~s/\\\\n/\\n/g} s{<link[^>]*href=\"[^\"]*${href##*/}\"[^>]*>}{<style>\n\$css\n</style>}g" "$OUTPUT"
  else
    echo "  ⚠ skipping: $href (not found)" >&2
  fi
done < <(grep -oP 'href="\K[^"]*(?=")' "$OUTPUT" | grep -E '\.css$' || true)

# 2. Replace <script src="..."> with inline <script>
while IFS= read -r src; do
  js_file="$INPUT_DIR/$src"
  if [[ ! -f "$js_file" ]]; then
    js_file="$(cd "$INPUT_DIR" && realpath "$src" 2>/dev/null || echo "")"
  fi
  if [[ ! -f "$js_file" ]]; then
    js_file="$ASSETS_DIR/${src##*/}"
  fi

  if [[ -f "$js_file" ]]; then
    content="$(inline "$js_file")"
    escaped_content="$(echo "$content" | sed 's/\\/\\\\/g' | sed 's/\//\\\//g' | sed 's/&/\\&/g' | tr '\n' '\f' | sed 's/\f/\\n/g')"
    perl -i -pe "BEGIN{\$js=qq{$escaped_content}; \$js=~s/\\\\n/\\n/g} s{<script[^>]*src=\"[^\"]*${src##*/}\"[^>]*></script>}{<script>\n\$js\n</script>}g" "$OUTPUT"
  else
    echo "  ⚠ skipping: $src (not found)" >&2
  fi
done < <(grep -oP 'src="\K[^"]*(?=")' "$OUTPUT" | grep -E '\.js$' || true)

echo "✔ bundled → $OUTPUT"
