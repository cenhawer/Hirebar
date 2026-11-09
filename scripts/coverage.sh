#!/bin/sh

set -eu
cd "$(dirname "$0")/.."

BUILD_PATH=${HIREBAR_BUILD_PATH:-.build}
MINIMUM=$(tr -d '[:space:]' <.coverage-minimum)
REPORT_DIR=coverage

swift test --enable-code-coverage --scratch-path "$BUILD_PATH"
PROFILE="$(dirname "$(swift test --scratch-path "$BUILD_PATH" --show-codecov-path)")/default.profdata"

set --
for BUNDLE in "$BUILD_PATH"/debug/*.xctest; do
	set -- "$@" -object "$BUNDLE/Contents/MacOS/$(basename "$BUNDLE" .xctest)"
done

mkdir -p "$REPORT_DIR"
CODECOV_JSON="$REPORT_DIR/codecov.json"
xcrun llvm-cov export -summary-only -instr-profile="$PROFILE" "$@" >"$CODECOV_JSON"

python3 -I - "$CODECOV_JSON" "$PWD/Sources/" "$MINIMUM" <<'PYTHON'
import json
import pathlib
import sys

codecov_path, sources_prefix, minimum = sys.argv[1], sys.argv[2], float(sys.argv[3])
files = {file["filename"]: file for entry in json.load(open(codecov_path))["data"] for file in entry["files"]}.values()
source_files = [file for file in files if file["filename"].startswith(sources_prefix)]
covered = sum(file["summary"]["lines"]["covered"] for file in source_files)
total = sum(file["summary"]["lines"]["count"] for file in source_files)
percent = 100 * covered / total if total else 0

for file in sorted(source_files, key=lambda file: file["summary"]["lines"]["percent"]):
    print(f'{file["summary"]["lines"]["percent"]:6.2f}%  {file["filename"][len(sources_prefix):]}')
measured = {file["filename"][len(sources_prefix):] for file in source_files}
unmeasured = sorted(
    str(path.relative_to(sources_prefix))
    for path in pathlib.Path(sources_prefix).rglob("*.swift")
    if str(path.relative_to(sources_prefix)) not in measured
)
for name in unmeasured:
    print(f"   n/a   {name}")
print(f"Line coverage of measured Sources: {percent:.2f}% (minimum {minimum:.2f}%)")
print(f"Source files without any test: {len(unmeasured)} of {len(measured) + len(unmeasured)}")

if percent < minimum:
    sys.exit(f"Coverage {percent:.2f}% is below the minimum {minimum:.2f}%")
PYTHON
