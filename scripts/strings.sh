#!/bin/sh

set -eu
cd "$(dirname "$0")/.."

CATALOG=Resources/Localizable.xcstrings
SCRATCH=${HIREBAR_STRINGS_PATH:-${TMPDIR:-/tmp}/hirebar-strings}
EXTRACTED="$SCRATCH/stringsdata"

mkdir -p "$EXTRACTED"
swift build --scratch-path "$SCRATCH/build" --product Hirebar \
	-Xswiftc -emit-localized-strings -Xswiftc -emit-localized-strings-path -Xswiftc "$EXTRACTED" >/dev/null

python3 - "$CATALOG" "$EXTRACTED" "${1:-}" <<'PY'
import glob, json, os, sys

catalog_path, extracted, mode = sys.argv[1], sys.argv[2], sys.argv[3]
found = {}
for path in sorted(glob.glob(os.path.join(extracted, "*.stringsdata"))):
    with open(path) as handle:
        data = json.load(handle)
    if not os.path.exists(data.get("source", "")):
        continue
    for entries in data.get("tables", {}).values():
        for entry in entries:
            found.setdefault(entry["key"], entry.get("comment", ""))
current = {"sourceLanguage": "es", "strings": {}, "version": "1.0"}
if os.path.exists(catalog_path):
    with open(catalog_path) as handle:
        current = json.load(handle)
strings = {}
for key in sorted(found):
    entry = dict(current["strings"].get(key, {}))
    if found[key]:
        entry["comment"] = found[key]
    strings[key] = entry
updated = {"sourceLanguage": current.get("sourceLanguage", "es"), "strings": strings, "version": current.get("version", "1.0")}
text = json.dumps(updated, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
previous = open(catalog_path).read() if os.path.exists(catalog_path) else ""
if mode == "--check":
    if text != previous:
        print(f"{catalog_path} no está al día: corre scripts/strings.sh y commitea el resultado")
        sys.exit(1)
    print(f"{catalog_path} al día ({len(strings)} textos)")
else:
    with open(catalog_path, "w") as handle:
        handle.write(text)
    print(f"{catalog_path}: {len(strings)} textos")
PY
