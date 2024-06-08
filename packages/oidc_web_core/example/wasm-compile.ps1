# see https://dart.dev/web/wasm#compiling-to-wasm
dart compile wasm web/main.dart -o site/main.wasm
# copy all files from web/ to site/
cp -r web/* site/
# except main.dart
rm site/main.dart

