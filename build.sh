#!/bin/bash

set -e

dlarch="$1"
if [ "$1" == "amd64" ]; then
    dlarch="x64_64"
fi

frameworkver="$2"

# CLICK_ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)
CLICK_ARCH="arm64"
CLICK_FRAMEWORK=$frameworkver

pkgver=4.2.923
srcdir=$ROOT
pkgdir=$INSTALL_DIR
pkgfile=Beeper-$pkgver-$dlarch.AppImage

if [ -f "$pkgfile" ]; then
    rm "$pkgfile"
fi

mkdir -p $pkgdir

# Various common environment variables
export PKG_CONFIG_PATH=$pkgdir/lib/pkgconfig:$pkgdir/share/pkgconfig:$PKG_CONFIG_PATH
export LD_LIBRARY_PATH=$pkgdir/lib:$LD_LIBRARY_PATH

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.5/install.sh | bash
\. "$HOME/.nvm/nvm.sh"

nvm install 24
npm install @electron/asar

DL_URL="https://api.beeper.com/desktop/download/linux/arm64/stable/com.automattic.beeper.desktop"

FILENAME=$(
  curl -v -L --no-progress-meter -r 0-1 "$DL_URL" 2>&1 > /dev/null \
    | grep "GET /builds/" \
    | sed -E 's@^.*GET /builds/([^ ]+) HTTP/2.*$@\1@'
)

# Pull Beeper AppImage
wget $DL_URL -O "$FILENAME"
chmod +x ./"$FILENAME"
./"$FILENAME" --appimage-extract

# fix apprun script
sed -Ei \
  's@^(if \[ -z \"\$APPDIR\" ] ; then)$@APPDIR="/'"$INSTALL_DIR"'/beeper"\n\1@' \
  "squashfs-root/AppRun"

# apprun script
install -Dm755 "$srcdir/squashfs-root/AppRun" "$pkgdir/usr/bin/beeper"

# The app source is now packed into an asar archive (resources/app.asar) with
# native modules kept in resources/app.asar.unpacked. To patch the source we
# extract the archive, edit it, then repack preserving the same unpacked set.
ASAR_FILE="squashfs-root/resources/app.asar"
EXTRACT_DIR="app.asar.extracted"

asar extract "$ASAR_FILE" "$EXTRACT_DIR"

# replace registerLinuxConfig function
# Find the file that exports registerLinuxConfig and replace the export statement.
# The upstream filename has changed across versions (e.g. linux-*.mjs, main-entry-*.mjs),
# so locate it by content instead of hardcoding the name.
MAIN_DIR="$EXTRACT_DIR/build/main"
LINUX_CONFIG_FILE=$(grep -lE 'export\{[a-zA-Z0-9_]+ as registerLinuxConfig\};' "$MAIN_DIR"/*.mjs | head -n1)
if [ -z "$LINUX_CONFIG_FILE" ]; then
  echo "error: could not find file exporting registerLinuxConfig in $MAIN_DIR" >&2
  return 1
fi
sed -i 's/export{[a-zA-Z0-9_]* as registerLinuxConfig};/const noopFunc=function(){};export{noopFunc as registerLinuxConfig};/' "$LINUX_CONFIG_FILE"

# repack into a new asar, unpacking the same files as the original
# exact list of currently-unpacked files, used as the repack --unpack glob
UNPACKED_GLOB="{$(cd "$ASAR_FILE.unpacked" && find . -type f | sed -E 's,^\./,,' | paste -s -d, -)}"
asar pack --unpack "$EXTRACT_DIR/$UNPACKED_GLOB" "$EXTRACT_DIR" app.asar.new
mv app.asar.new "$ASAR_FILE"

cp -r squashfs-root/* "$pkgdir/"
rm -f "$pkgdir/beepertexts.desktop"   # remove upstream desktop file

# fix permissions
chmod -R u+rwX,go+rX,go-w "$pkgdir"

cp $ROOT/manifest.json $pkgdir/
sed -i "s/@CLICK_ARCH@/$CLICK_ARCH/g" $pkgdir/manifest.json
sed -i "s/@CLICK_FRAMEWORK@/$CLICK_FRAMEWORK/g" $pkgdir/manifest.json
cp $ROOT/beeper.apparmor $pkgdir/
cp $ROOT/beeper.desktop $pkgdir/
cp $ROOT/beeper.wrapper $pkgdir/
chmod a+x $pkgdir/beeper.wrapper
#chown root $pkgdir/chrome-sandbox
#chmod 4755 $pkgdir/chrome-sandbox

exit 0
