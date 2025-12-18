# README.md — ZM Apps WebView (Android)

## 1. Требования
- Flutter SDK 3.16+
- Android SDK / Android Studio (Java 17)
- Firebase (Realtime Database + FCM)
- AppsFlyer Dev Key (опционально)
- Устройство с Play Services

## 2. Зависимости (pubspec.yaml)
```yaml
dependencies:
  flutter:
    sdk: flutter
  url_launcher: ^6.3.2
  webview_flutter: ^4.13.0
  webview_flutter_wkwebview: ^3.23.5
  webview_flutter_android: ^4.10.11
  http: ^1.5.0
  device_info_plus: ^9.1.1
  package_info_plus: ^8.0.0
  firebase_core: ^3.2.0
  firebase_messaging: ^15.0.4
  firebase_analytics: ^11.1.0
  appsflyer_sdk: ^6.17.7+1
  advertising_id: ^2.0.0
  install_referrer:
    path: third_party/install_referrer
  shared_preferences: ^2.2.3
  uuid: ^4.4.0
  flutter_inappwebview: ^6.1.5
  permission_handler: ^11.3.1

dependency_overrides:
  flutter_inappwebview_android:
    path: third_party/flutter_inappwebview_android
```

## 3. Настройка Android

### 3.1 AndroidManifest.xml
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />

    <application
        android:usesCleartextTraffic="true"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
    </application>
</manifest>
```

### 3.2 build.gradle.kts (app)
```kotlin
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}
```

### 3.3 Firebase
Положить `google-services.json` в:
```
android/app/
```

### 3.4 AppsFlyer
```dart
const _appsflyerDevKey = '<your-key>';
const _appsflyerAppId = '';
```

### 3.5 File Chooser (форк)
Использовать `third_party/flutter_inappwebview_android`.

### 3.6 Runtime-права
Запрашиваются в WebView.

### 3.7 MainActivity
```
android/app/src/main/kotlin/com/example/zm_apps_webview_android/MainActivity.kt
```

```kotlin
package com.example.zm_apps_webview_android
import io.flutter.embedding.android.FlutterActivity
class MainActivity : FlutterActivity()
```

### 3.8 settings.gradle.kts
```kotlin
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
}
include(":app")
```

## 4. Логика старта
1. Тянем RTDB конфиг  
2. Строим endpoint  
3. Формируем payload  
4. POST → получаем passed и link  
5. Кэшируем state  
6. Открываем WebView или заглушку  

## 5. WebView
- Multiple windows  
- Popup stack  
- Deep links (`tg://`, `wa://`, `intent://`)  
- File chooser  
- Back навигация  

## 6. Запуск
```bash
flutter pub get
flutter run
```

## 7. Основные файлы
- lib/logic.dart  
- lib/webview.dart  
- android/app/AndroidManifest.xml  
- third_party/flutter_inappwebview_android  
- pubspec.yaml  

## 8. Чек‑лист переноса
- [ ] lib/  
- [ ] third_party/  
- [ ] dependency_overrides  
- [ ] google-services.json  
- [ ] Firebase RTDB  
- [ ] FCM  
- [ ] AppsFlyer  
- [ ] Manifest permissions  
- [ ] MainActivity  
- [ ] settings.gradle.kts  
- [ ] File chooser тест  
