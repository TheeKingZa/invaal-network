
#!/usr/bin/env bash

# Stop if a command fails, a variable is missing,
# or a command in a pipeline returns an error.
set -Eeuo pipefail

# Always run from the repository root.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

echo "======================================"
echo " InVaal [016] - Deployment checks"
echo "======================================"

# Make sure the homepage exists.
if [[ ! -f "index.html" ]]; then
  echo "ERROR: index.html was not found."
  exit 1
fi

# Remove the previous generated deployment folder.
rm -rf _site

# Check whitespace errors in tracked Git changes.
if command -v git >/dev/null 2>&1; then
  git diff --check
  echo "PASS: Git whitespace checks"
fi

# Require Python for JSON validation and preparing the site.
if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: Python 3 is required."
  exit 1
fi

# Validate all project JSON files.
python3 - <<'PY'
import json
import sys
from pathlib import Path

ignored = {".git", ".github", "node_modules", "_site"}

files = [
    path for path in Path(".").rglob("*.json")
    if not any(part in ignored for part in path.parts)
]

for path in files:
    try:
        with path.open(encoding="utf-8") as file:
            json.load(file)
        print(f"PASS: {path}")
    except (json.JSONDecodeError, OSError) as error:
        print(f"ERROR: {path}: {error}", file=sys.stderr)
        sys.exit(1)

print(f"PASS: Validated {len(files)} JSON file(s)")
PY

# Require Node.js for JavaScript syntax validation.
if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: Node.js is required for JavaScript checks."
  exit 1
fi

# Check every project JavaScript file.
while IFS= read -r -d '' file; do
  echo "Checking JavaScript: $file"
  node --check "$file"
done < <(
  find . \
    \( -name .git -o -name .github -o -name node_modules -o -name _site \) -prune \
    -o -type f -name '*.js' -print0
)

echo "PASS: JavaScript syntax checks"

# Prepare a clean folder for GitHub Pages.
# Exclude Git files, development configuration, and this script.
python3 - <<'PY'
import shutil
from pathlib import Path

root = Path(".").resolve()
output = root / "_site"

excluded = {
    ".git",
    ".github",
    "node_modules",
    "_site",
    "README.md",
    "deploy.sh",
    ".gitignore",
}

def ignore_entries(directory, names):
    # Exclude development files and generated folders.
    return [
        name for name in names
        if name in excluded
    ]

shutil.copytree(
    root,
    output,
    ignore=ignore_entries,
    dirs_exist_ok=True,
)

if not (output / "index.html").is_file():
    raise SystemExit("ERROR: _site/index.html was not created.")

print("PASS: Created clean _site/ deployment folder")
print("PASS: _site/index.html exists")
PY

echo "======================================"
echo " All deployment checks passed!"
echo " Website files are ready in _site/"
echo "======================================"
