#!/bin/sh

set -eu
cd "$(dirname "$0")/.."

VERSION=$(tr -d '[:space:]' <VERSION)
APP=dist/Hirebar.app
BUILD_PATH=${HIREBAR_BUILD_PATH:-.build}
SIGN_IDENTITY=${HIREBAR_SIGN_IDENTITY:--}

echo "Building Hirebar ${VERSION}..."
swift build -c release --product Hirebar --scratch-path "$BUILD_PATH"
BIN_DIR=$(swift build -c release --scratch-path "$BUILD_PATH" --show-bin-path)

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Hirebar" "$APP/Contents/MacOS/Hirebar"
cp Resources/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
cp -R Resources/inicial "$APP/Contents/Resources/"
cp Resources/perfiles-ia.json "$APP/Contents/Resources/"
cp Resources/destinos.json "$APP/Contents/Resources/"
cp Resources/canal.json "$APP/Contents/Resources/"
cp Resources/herramientas.json "$APP/Contents/Resources/"
cp Resources/comandos.json "$APP/Contents/Resources/"
codesign --force --deep --sign "$SIGN_IDENTITY" "$APP"
echo "Built $APP"

case "${1:-}" in
	--install)
		pkill -x Hirebar 2>/dev/null || true
		sleep 1
		mkdir -p "$HOME/Applications"
		rm -rf "$HOME/Applications/Hirebar.app"
		cp -R "$APP" "$HOME/Applications/Hirebar.app"
		open "$HOME/Applications/Hirebar.app"
		echo "Installed in ~/Applications/Hirebar.app"
		;;
	--zip)
		(cd dist && ditto -c -k --keepParent Hirebar.app "Hirebar-$VERSION.zip")
		echo "Created dist/Hirebar-$VERSION.zip"
		;;
esac
