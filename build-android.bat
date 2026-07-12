flutter clean
flutter pub get
dart pub global activate fastforge
dart setup.dart android --out core
flutter build apk --release --obfuscate --split-debug-info=debug-symbols/ --split-per-abi