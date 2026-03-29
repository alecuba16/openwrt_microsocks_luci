#!/bin/sh
# Merge LuCI microsocks UI into an existing microsocks .ipk and produce a new .ipk.
# OpenWrt .ipk files are either: (1) gzip-compressed tar, or (2) Unix ar with debian-binary + *.tar.gz
# Usage: ./repack-microsocks-ipk.sh [path/to/microsocks_*.ipk]
# Default input: ./microsocks_1.0.3-3_aarch64_cortex-a53.ipk (same directory as this script)

set -eu

# Avoid macOS extended attributes / AppleDouble when copying into the payload.
export COPYFILE_DISABLE=1

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
INPUT_IPK="${1:-$SCRIPT_DIR/microsocks_1.0.3-3_aarch64_cortex-a53.ipk}"
OVERLAY_HTDOC="$SCRIPT_DIR/luci-app-microsocks/htdocs"
OVERLAY_ROOT="$SCRIPT_DIR/luci-app-microsocks/root"

if ! test -f "$INPUT_IPK"; then
	echo "Input IPK not found: $INPUT_IPK" >&2
	echo "Place your microsocks_*.ipk next to this script or pass the path as the first argument." >&2
	exit 1
fi

# OpenWrt opkg/libtar does not accept POSIX PAX headers (typeflag 'x' / 0x78) that
# macOS tar emits by default. Build ustar-only tar.gz members (matches OpenWrt SDK).
TAR_BIN=tar
if ! tar -c --format ustar -f /dev/null /dev/null 2>/dev/null; then
	if command -v gtar >/dev/null 2>&1 && gtar -c --format ustar -f /dev/null /dev/null 2>/dev/null; then
		TAR_BIN=gtar
	else
		echo "This script needs a tar that supports --format ustar (macOS tar works; or: brew install gnu-tar)." >&2
		exit 1
	fi
fi

targz_ustar() {
	_out="$1"
	shift
	"$TAR_BIN" -c --format ustar -f - "$@" | gzip -9 -n > "$_out"
}

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT INT TERM

cd "$WORKDIR"

# Detect package format
if tar -tzf "$INPUT_IPK" >/dev/null 2>&1; then
	IPK_FORMAT=tar
	tar -xzf "$INPUT_IPK"
elif command -v ar >/dev/null 2>&1 && ar t "$INPUT_IPK" >/dev/null 2>&1; then
	IPK_FORMAT=ar
	ar x "$INPUT_IPK"
else
	echo "Unrecognized .ipk format (need gzip-tar or ar): $INPUT_IPK" >&2
	file "$INPUT_IPK" >&2 || true
	exit 1
fi

if ! test -f debian-binary || ! test -f control.tar.gz || ! test -f data.tar.gz; then
	echo "Unexpected IPK layout: expected debian-binary, control.tar.gz, data.tar.gz" >&2
	exit 1
fi

mkdir -p control data
tar -xzf control.tar.gz -C control
tar -xzf data.tar.gz -C data

# Install LuCI static files (OpenWrt installs htdocs under /www)
if test -d "$OVERLAY_HTDOC/luci-static"; then
	mkdir -p data/www
	cp -a "$OVERLAY_HTDOC/luci-static" data/www/
fi

# Install menu + ACL under /usr/share
if test -d "$OVERLAY_ROOT/usr/share/luci"; then
	mkdir -p data/usr/share
	cp -a "$OVERLAY_ROOT/usr/share/luci" data/usr/share/
fi
if test -d "$OVERLAY_ROOT/usr/share/rpcd"; then
	mkdir -p data/usr/share
	cp -a "$OVERLAY_ROOT/usr/share/rpcd" data/usr/share/
fi

# Install Lua controller + CBI model (for Lua-based LuCI, e.g. older QWRT)
if test -d "$OVERLAY_ROOT/usr/lib/lua"; then
	mkdir -p data/usr/lib
	cp -a "$OVERLAY_ROOT/usr/lib/lua" data/usr/lib/
fi

CONTROL_FILE="control/control"
if ! test -f "$CONTROL_FILE"; then
	echo "Missing control/control in control.tar.gz" >&2
	exit 1
fi

# Append luci-base to Depends
if grep -q '^Depends:' "$CONTROL_FILE"; then
	if ! grep '^Depends:' "$CONTROL_FILE" | grep -q 'luci-base'; then
		if sed --version >/dev/null 2>&1; then
			sed -i 's/^Depends: \(.*\)$/Depends: \1, luci-base/' "$CONTROL_FILE"
		else
			sed -i '' 's/^Depends: \(.*\)$/Depends: \1, luci-base/' "$CONTROL_FILE"
		fi
	fi
else
	printf '\nDepends: luci-base\n' >> "$CONTROL_FILE"
fi

# Note merged build in Description (best-effort)
if grep -q '^Description:' "$CONTROL_FILE"; then
	if ! grep '^Description:' "$CONTROL_FILE" | grep -q '(with LuCI)'; then
		if sed --version >/dev/null 2>&1; then
			sed -i 's/^Description: \(.*\)$/Description: \1 (with LuCI)/' "$CONTROL_FILE"
		else
			sed -i '' 's/^Description: \(.*\)$/Description: \1 (with LuCI)/' "$CONTROL_FILE"
		fi
	fi
fi

# postinst: reload rpcd so ACL is picked up; uhttpd serves new static files
POSTINST="control/postinst"
MARK="# luci-app-microsocks-repack-v4"
POSTINST_SNIPPET="$MARK
rm -f /tmp/luci-indexcache /tmp/luci-indexcache.* /tmp/luci-modulecache/* 2>/dev/null || true
[ -x /etc/init.d/rpcd ] && /etc/init.d/rpcd restart 2>/dev/null || true
# Full restart clears dispatcher in-memory menu tree (reload is not always enough).
[ -x /etc/init.d/uhttpd ] && /etc/init.d/uhttpd restart 2>/dev/null || true
"
if test -f "$POSTINST"; then
	if ! grep -q "$MARK" "$POSTINST" 2>/dev/null; then
		printf '\n%s\n' "$POSTINST_SNIPPET" >> "$POSTINST"
		chmod 755 "$POSTINST"
	fi
else
	{
		echo '#!/bin/sh'
		printf '%s\n' "$POSTINST_SNIPPET"
		echo 'exit 0'
	} > "$POSTINST"
	chmod 755 "$POSTINST"
fi

(cd control && targz_ustar ../control.tar.gz .)
(cd data && targz_ustar ../data.tar.gz .)

BASE="$(basename "$INPUT_IPK" .ipk)"
OUTPUT_IPK="$SCRIPT_DIR/${BASE}+luci.ipk"

rm -f "$OUTPUT_IPK"

if test "$IPK_FORMAT" = tar; then
	targz_ustar "$OUTPUT_IPK" debian-binary control.tar.gz data.tar.gz
else
	ar rcs "$OUTPUT_IPK" debian-binary control.tar.gz data.tar.gz
fi

echo "Created: $OUTPUT_IPK"
echo "On the router: opkg install --force-reinstall $(basename "$OUTPUT_IPK")"
echo "You need luci-base (and a LuCI admin UI) already installed, or install them first."
