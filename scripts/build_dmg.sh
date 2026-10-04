#!/bin/bash
#
# 编译 Release 并打包成 DMG。
#   ./scripts/build_dmg.sh            # 正常签名构建
#   UNSIGNED=1 ./scripts/build_dmg.sh # 不签名构建（本机自用/测试）
#
# 产物：.build/magicallyEncircle.dmg
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

PROJECT="magicallyEncircle.xcodeproj"
SCHEME="magicallyEncircle"
CONFIGURATION="Release"
DERIVED="$PROJECT_DIR/.build"
APP_NAME="magicallyEncircle.app"
STAGE="$DERIVED/dmg-stage"
DMG_PATH="$DERIVED/magicallyEncircle.dmg"

SIGN_ARGS=()
if [ "${UNSIGNED:-0}" = "1" ]; then
  SIGN_ARGS+=("CODE_SIGNING_ALLOWED=NO" "CODE_SIGNING_REQUIRED=NO")
  echo "==> 以未签名方式构建"
fi

echo "==> 编译 $CONFIGURATION"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED" \
  "${SIGN_ARGS[@]}" \
  build

APP_PATH="$DERIVED/Build/Products/$CONFIGURATION/$APP_NAME"
if [ ! -d "$APP_PATH" ]; then
  echo "找不到 $APP_PATH" >&2
  exit 1
fi

echo "==> 准备 DMG 内容"
rm -rf "$STAGE" "$DMG_PATH"
mkdir -p "$STAGE"
cp -R "$APP_PATH" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "==> 生成 DMG"
hdiutil create -volname "magicallyEncircle" -srcfolder "$STAGE" -ov -format UDZO "$DMG_PATH"

echo ""
echo "完成：$DMG_PATH"
echo "打开 DMG，把 magicallyEncircle.app 拖到 Applications 即可。"
