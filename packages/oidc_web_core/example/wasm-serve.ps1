.\wasm-compile.ps1
dart pub global activate dhttpd
dart pub global run dhttpd --path site --port 22433 --host 127.0.0.1

Start http://127.0.0.1:22433/