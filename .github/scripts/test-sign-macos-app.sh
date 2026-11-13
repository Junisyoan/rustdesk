#!/usr/bin/env bash

set -euo pipefail

test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
app_path="$test_dir/RustDesk.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Frameworks"
plutil -create xml1 "$app_path/Contents/Info.plist"
plutil -insert CFBundleExecutable -string RustDesk "$app_path/Contents/Info.plist"
plutil -insert CFBundleIdentifier -string com.carriez.rustdesk.signing-test "$app_path/Contents/Info.plist"
printf 'int test_version(void) { return 0; }\n' | clang -x c -dynamiclib -install_name @executable_path/../Frameworks/libtest.dylib -o "$app_path/Contents/Frameworks/libtest.dylib" -
printf 'int test_version(void); int main(void) { return test_version(); }\n' | clang -x c - -L"$app_path/Contents/Frameworks" -ltest -o "$app_path/Contents/MacOS/RustDesk"

bash ./.github/scripts/sign-macos-app.sh "$app_path" - ./flutter/macos/Runner/Release.entitlements
cp "$app_path/Contents/MacOS/RustDesk" "$app_path/Contents/MacOS/service"
if codesign --verify --deep --strict "$app_path"; then
  echo "Adding service should invalidate the original bundle signature" >&2
  exit 1
fi
bash ./.github/scripts/sign-macos-app.sh "$app_path" - ./flutter/macos/Runner/Release.entitlements
codesign --verify --deep --strict "$app_path"
"$app_path/Contents/MacOS/RustDesk"
"$app_path/Contents/MacOS/service"
