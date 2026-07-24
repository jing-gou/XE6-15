#!/usr/bin/env python3
"""Bundle html-ppt into a standalone HTML file with all CSS/JS inlined."""

import sys, os, re
from pathlib import Path

def resolve(input_dir, href, assets_dir):
    """Resolve a relative href to an absolute file path."""
    candidates = [
        os.path.join(input_dir, href),
        os.path.join(assets_dir, os.path.basename(href)),
        os.path.join(assets_dir, "themes", os.path.basename(href)),
        os.path.join(assets_dir, "animations", os.path.basename(href)),
    ]
    for c in candidates:
        real = os.path.realpath(c)
        if os.path.isfile(real):
            return real
    return None

def main():
    if len(sys.argv) < 2:
        print("usage: bundle.py <input.html> [output.html]", file=sys.stderr)
        sys.exit(1)

    input_path = os.path.abspath(sys.argv[1])
    output_path = sys.argv[2] if len(sys.argv) > 2 else input_path.replace(".html", "-standalone.html")
    input_dir = os.path.dirname(input_path)
    assets_dir = os.path.realpath(os.path.join(input_dir, "../../.claude/skills/html-ppt/assets"))

    print(f"input:  {input_path}")
    print(f"output: {output_path}")
    print(f"assets: {assets_dir}")

    with open(input_path, "r", encoding="utf-8") as f:
        html = f.read()

    # Replace <link rel="stylesheet" href="..."> with inline <style>
    def replace_css(m):
        tag = m.group(0)
        href_match = re.search(r'href="([^"]*)"', tag)
        if not href_match:
            return tag
        href = href_match.group(1)
        if not href.endswith(".css"):
            return tag
        resolved = resolve(input_dir, href, assets_dir)
        if not resolved:
            print(f"  ⚠ CSS not found: {href}", file=sys.stderr)
            return tag
        with open(resolved, "r", encoding="utf-8") as f:
            content = f.read()
        print(f"  ✔ CSS inlined: {os.path.basename(resolved)}")
        return f"<style>\n{content}\n</style>"

    html = re.sub(r'<link[^>]*rel="stylesheet"[^>]*/?>', replace_css, html)

    # Replace <script src="..."></script> with inline <script>
    def replace_js(m):
        tag = m.group(0)
        src_match = re.search(r'src="([^"]*)"', tag)
        if not src_match:
            return tag
        src = src_match.group(1)
        if not src.endswith(".js"):
            return tag
        resolved = resolve(input_dir, src, assets_dir)
        if not resolved:
            print(f"  ⚠ JS not found: {src}", file=sys.stderr)
            return tag
        with open(resolved, "r", encoding="utf-8") as f:
            content = f.read()
        print(f"  ✔ JS  inlined: {os.path.basename(resolved)}")
        return f"<script>\n{content}\n</script>"

    html = re.sub(r'<script[^>]*src="[^"]*"[^>]*></script>', replace_js, html)

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(html)

    size_kb = os.path.getsize(output_path) / 1024
    print(f"\n✔ bundled → {output_path}  ({size_kb:.0f} KB)")

if __name__ == "__main__":
    main()
