flutter clean
flutter pub get
dart pub global activate fastforge
dart setup.dart android --out core
dart pub global run fastforge:main release --name stable-android