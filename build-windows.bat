flutter clean
flutter pub get
dart pub global activate fastforge
dart setup.dart windows --out service --arch amd64
dart pub global run fastforge:main release --name stable-windows