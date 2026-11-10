#!/bin/sh
set -eu
cd "$(dirname "$0")"
swift icon.swift AppIcon.iconset
iconutil -c icns AppIcon.iconset -o AppIcon.icns
swiftc -target arm64-apple-macos14.0 -parse-as-library Sources/*.swift -o TaskTide -framework SwiftUI -framework AppKit
python3 package.py
ditto -c -k --sequesterRsrc --keepParent 'dist/任务潮汐.app' 'dist/TaskTide-1.1.0-macOS-arm64.zip'
echo 'Built dist/TaskTide-1.1.0-macOS-arm64.zip'
