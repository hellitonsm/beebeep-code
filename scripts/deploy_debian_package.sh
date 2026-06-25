#!/bin/bash
set -e

# --- CONFIGURATION ---
# The name of the package
PACKAGE_NAME="beebeep"

# The upstream software version (matches CHANGELOG.txt)
VERSION="5.9.1"

# The package revision number (pure numeric as per your instruction)
PKG_REVISION="1"

# Custom separator for the distribution and architecture suffixes in the final filename
VERSION_SEPARATOR="_"

# The package maintainer information
MAINTAINER="Marco Mastroddi <marco.mastroddi@gmail.com>"


# --- AUTOMATIC ENVIRONMENT DETECTION & SETUP ---
# Detect current Debian major version number (e.g., "12" or "13")
DEBIAN_VERSION_NUM=$(cut -d. -f1 /etc/debian_version)

# Automatically detect the current system architecture (e.g., amd64, i386, arm64)
ARCH=$(dpkg --print-architecture)

# Pure Debian Revision for the internal changelog (e.g., "-1")
DEBIAN_REVISION="-${PKG_REVISION}"

# Dynamically fetch the current year for copyright files
CYEAR=$(date +%Y)


# --- PATHS SPECIFICATION ---
# Posix-compliant method to detect the source directory path (parent of the "scripts" folder)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="$(dirname "$SCRIPT_DIR")"

# Dynamic build directory structure inside beebeep-code/build/debianX/
BUILD_ROOT="$SOURCE_DIR/build"
BUILD_DIR="$BUILD_ROOT/debian${DEBIAN_VERSION_NUM}"

echo "=== Starting Debian ${DEBIAN_VERSION_NUM} package preparation ==="
echo "Source directory detected: $SOURCE_DIR"
echo "Build directory set to: $BUILD_DIR"
echo "Detected Architecture: $ARCH"
echo "Internal Package Version: ${VERSION}${DEBIAN_REVISION}"

# Environment cleanup and build directory creation
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/${PACKAGE_NAME}-${VERSION}"

# Safely copy source files
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory $SOURCE_DIR does not exist."
    exit 1
fi
echo "Copying source files..."
rsync -a \
    --exclude='scripts' \
    --exclude='build' \
    --exclude='trash' \
    --exclude='test' \
    --exclude='openssl' \
    --exclude='*.ts' \
    --exclude='*.sh' \
    "$SOURCE_DIR/" "$BUILD_DIR/${PACKAGE_NAME}-${VERSION}/"

cd "$BUILD_DIR/${PACKAGE_NAME}-${VERSION}"

# Create the mandatory 'debian' directory structure
mkdir -p debian
mkdir -p debian/source

# File: debian/source/format
echo "3.0 (quilt)" > debian/source/format

# File: debian/control
cat <<EOF > debian/control
Source: $PACKAGE_NAME
Section: comm
Priority: optional
Maintainer: $MAINTAINER
Build-Depends: debhelper-compat (= 13), qtbase5-dev, qtmultimedia5-dev, libqt5x11extras5-dev, libxcb-screensaver0-dev
Standards-Version: 4.6.2
Homepage: https://www.beebeep.net

Package: $PACKAGE_NAME
Architecture: $ARCH
Depends: \${shlibs:Depends}, \${misc:Depends}, gstreamer1.0-plugins-base
Description: Free office messenger
 This office messaging application, BeeBEEP, does not need an external
 server to let users communicate with each other. In your office, in your
 laboratory, at school, at home, in the hospital or in any other activity
 having the need for security and privacy, BeeBEEP is the best way to keep
 your private messages safe.
EOF

# File: debian/copyright
cat <<EOF > debian/copyright
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: beebeep
Source: https://www.beebeep.net

Files: *
Copyright: 2010-$CYEAR Marco Mastroddi <marco.mastroddi@gmail.com>
License: GPL-3.0+

License: GPL-3.0+
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 .
 On Debian systems, the complete text of the GNU General Public
 License version 3 can be found in "/usr/share/common-licenses/GPL-3".
EOF

# File: debian/changelog
DEB_DATE=$(date -R)
CHANGELOG_INPUT="$SOURCE_DIR/CHANGELOG.txt"

if [ ! -f "$CHANGELOG_INPUT" ]; then
    echo "Error: Local CHANGELOG.txt not found in $SOURCE_DIR"
    exit 1
fi

BUG_COUNT=$(awk -v main_ver="$VERSION" '
BEGIN { counting = 0; rows = 0; }
/^BeeBEEP [0-9]+/ {
    if (counting == 1) { exit; }
    if ($2 == main_ver) { counting = 1; }
    next;
}
/^- / { if (counting == 1) { rows++; } }
END { print rows; }' "$CHANGELOG_INPUT")

if [ -z "$BUG_COUNT" ] || [ "$BUG_COUNT" -eq 0 ]; then
    BUG_ID="1045000"
else
    BUG_ID=$((1045000 + BUG_COUNT))
fi

> debian/changelog

awk -v pkg="$PACKAGE_NAME" -v main_ver="$VERSION" -v deb_rev="$DEBIAN_REVISION" -v maint="$MAINTAINER" -v ddate="$DEB_DATE" -v bug_id="$BUG_ID" '
BEGIN {
    printing = 0;
    count_items = 0;
}
/^BeeBEEP [0-9]+/ {
    current_ver = $2;
    
    if (printing == 1) {
        print "" >> "debian/changelog";
        print " -- " maint "  " ddate >> "debian/changelog";
        printing = 0;
        exit;
    }
    
    if (current_ver == main_ver) {
        printing = 1;
        print pkg " (" current_ver deb_rev ") unstable; urgency=low" >> "debian/changelog";
        print "" >> "debian/changelog";
    }
    next;
}
/^- / {
    if (printing == 1) {
        sub(/^- /, "");
        
        if (count_items == 0) {
            full_line = $0 " (Closes: #" bug_id ")";
        } else {
            full_line = $0;
        }
        count_items++;

        split(full_line, words, " ");
        current_out = "  *";
        
        for (i = 1; i <= length(words); i++) {
            if (length(current_out) + length(words[i]) + 1 > 75) {
                print current_out >> "debian/changelog";
                current_out = "    " words[i];
            } else {
                current_out = current_out " " words[i];
            }
        }
        if (length(current_out) > 0) {
            print current_out >> "debian/changelog";
        }
    }
}
END {
    if (printing == 1) {
        print "" >> "debian/changelog";
        print " -- " maint "  " ddate >> "debian/changelog";
    }
}' "$CHANGELOG_INPUT"

# File: debian/rules
cat <<EOF > debian/rules
#!/usr/bin/make -f

%:
	dh \$@

override_dh_auto_configure:
	qmake -makefile PREFIX=/usr QMAKE_CFLAGS_RELEASE="\$(CFLAGS)" QMAKE_CXXFLAGS_RELEASE="\$(CXXFLAGS)" beebeep-desktop.pro

override_dh_auto_install:
	mkdir -p debian/$PACKAGE_NAME/usr/bin
	mkdir -p debian/$PACKAGE_NAME/usr/share/$PACKAGE_NAME
	mkdir -p debian/$PACKAGE_NAME/usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)/$PACKAGE_NAME
	
	cp test/beebeep debian/$PACKAGE_NAME/usr/bin/
	
	cp test/libregularboldtextmarker.so* debian/$PACKAGE_NAME/usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)/$PACKAGE_NAME/
	cp test/librainbowtextmarker.so* debian/$PACKAGE_NAME/usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)/$PACKAGE_NAME/
	cp test/libnumbertextmarker.so* debian/$PACKAGE_NAME/usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)/$PACKAGE_NAME/
	
	cp src/images/beebeep.png debian/$PACKAGE_NAME/usr/share/$PACKAGE_NAME/
	cp locale/*.qm debian/$PACKAGE_NAME/usr/share/$PACKAGE_NAME/
	cp misc/beep.wav debian/$PACKAGE_NAME/usr/share/$PACKAGE_NAME/
EOF
chmod +x debian/rules

# File: Create official .desktop file
mkdir -p debian/usr/share/applications
cat <<EOF > debian/$PACKAGE_NAME.desktop
[Desktop Entry]
Name=BeeBEEP
Version=1.0
Exec=beebeep
Comment=BeeBEEP free office messenger
Icon=beebeep
Type=Application
Terminal=false
StartupNotify=false
Categories=Office;InstantMessaging;
EOF

mkdir -p debian/usr/share/pixmaps
ln -sf /usr/share/beebeep/beebeep.png debian/usr/share/pixmaps/beebeep.png

# File: Create official Manual Page
cat <<EOF > debian/beebeep.1
.TH BEEBEEP 1 "$(date +'%B %Y')" "$VERSION" "BeeBEEP Manual"
.SH NAME
beebeep \- Free security-oriented office messenger
.SH SYNOPSIS
.B beebeep
.SH DESCRIPTION
.B BeeBEEP
is a secure, open source, peer-to-peer office messenger that does not require
a centralized server. It works out of the box inside your local area network (LAN).
.SH OPTIONS
This application does not accept standard command line options. All configuration
is handled internally via user interface or INI/RC configuration files.
.SH AUTHOR
BeeBEEP was written by Marco Mastroddi <marco.mastroddi@gmail.com>.
EOF

echo "debian/beebeep.1" > debian/beebeep.manpages

# PACKAGE COMPILATION
echo "=== Building package using dpkg-buildpackage ==="
dpkg-buildpackage -us -uc -b

# --- POST-BUILD CUSTOM FILENAME RENAMING ---
echo "=== Customizing generated filenames with OS and Architecture tags ==="

# Sanitize version string for use in filenames (remove slashes, spaces)
DEBIAN_VERSION_TAG=$(echo "$DEBIAN_VERSION_NUM" | tr -c '[:alnum:].-' '-')

# Define the default filenames generated by dpkg-buildpackage
STANDARD_NAME="${PACKAGE_NAME}_${VERSION}-${PKG_REVISION}_${ARCH}"
STANDARD_BUILDINFO="${PACKAGE_NAME}_${VERSION}-${PKG_REVISION}_${ARCH}.buildinfo"
STANDARD_CHANGES="${PACKAGE_NAME}_${VERSION}-${PKG_REVISION}_${ARCH}.changes"

# Define your custom preferred filenames using underscores
CUSTOM_NAME="${PACKAGE_NAME}_${VERSION}-${PKG_REVISION}${VERSION_SEPARATOR}debian${DEBIAN_VERSION_TAG}${VERSION_SEPARATOR}${ARCH}.deb"
CUSTOM_BUILDINFO="${PACKAGE_NAME}_${VERSION}-${PKG_REVISION}${VERSION_SEPARATOR}debian${DEBIAN_VERSION_TAG}${VERSION_SEPARATOR}${ARCH}.buildinfo"
CUSTOM_CHANGES="${PACKAGE_NAME}_${VERSION}-${PKG_REVISION}${VERSION_SEPARATOR}debian${DEBIAN_VERSION_TAG}${VERSION_SEPARATOR}${ARCH}.changes"

# Rename the files inside the build directory if they exist
cd "$BUILD_DIR"

if [ -f "${STANDARD_NAME}.deb" ]; then
    mv "${STANDARD_NAME}.deb" "$CUSTOM_NAME" 2>/dev/null || true
    echo "Package available at: $CUSTOM_NAME"
fi

if [ -f "$STANDARD_BUILDINFO" ]; then
    mv "$STANDARD_BUILDINFO" "$CUSTOM_BUILDINFO"
fi

if [ -f "$STANDARD_CHANGES" ]; then
    mv "$STANDARD_CHANGES" "$CUSTOM_CHANGES"
fi

echo "=== Build completed successfully! ==="
echo "Generated files are located in: $BUILD_DIR"
ls -l "$BUILD_DIR"

