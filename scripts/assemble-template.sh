#!/bin/sh
# Assembles Rivlet.app/Contents/Helpers/RivletTemplate.app from the built
# RivletStub tool and the template Info.plist, then signs it with the same
# identity as the app so notarization and --deep verification pass. Runs as
# a build phase of the Rivlet target; Xcode signs the outer app afterwards.
set -eu

TEMPLATE="$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH/Helpers/RivletTemplate.app"
rm -rf "$TEMPLATE"
mkdir -p "$TEMPLATE/Contents/MacOS" "$TEMPLATE/Contents/Resources"
cp "$BUILT_PRODUCTS_DIR/RivletStub" "$TEMPLATE/Contents/MacOS/RivletStub"
cp "$SRCROOT/RivletStub/Template/Info.plist" "$TEMPLATE/Contents/Info.plist"
printf 'APPL????' > "$TEMPLATE/Contents/PkgInfo"

IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:--}"
if [ "$IDENTITY" = "-" ]; then
    codesign --force --sign - "$TEMPLATE"
else
    # shellcheck disable=SC2086
    codesign --force --sign "$IDENTITY" ${OTHER_CODE_SIGN_FLAGS:-} "$TEMPLATE"
fi
echo "Assembled $TEMPLATE"
