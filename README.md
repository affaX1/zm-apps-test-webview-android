# ZM Apps WebView (Android) — полная инструкция

Приложение на Flutter, которое подтягивает конфиг, отправляет данные устройства, кэширует ответ и открывает ссылку в встроенном WebView. Добавлен кастомный Android file chooser, чтобы после съёмки фото/видео имя файла корректно отображалось в `<input type="file">`.

---

## 1) Требования
- Flutter SDK 3.16+ (соответствует `pubspec.yaml`)
- Android SDK / Android Studio (Java 17)
- Firebase (Realtime Database + FCM)
- AppsFlyer Dev Key (если нужен реальный `appsflyer_id`)
- Реальное устройство или эмулятор с Play Services (для FCM токена)

---

## 2) Зависимости (`pubspec.yaml`)
Уже подключены:
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
Установка:
```bash
flutter pub get
```
> При переносе в другой проект: скопируйте `third_party/flutter_inappwebview_android` и оставьте блок `dependency_overrides` — он содержит правку file chooser.

---

## 3) Настройка Android

### 3.1 Манифест (`android/app/src/main/AndroidManifest.xml`)
Внутри `<manifest>`:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Права -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />

    <application
        android:usesCleartextTraffic="true"
        android:label="zm_apps_webview_android"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <!-- остальное содержимое application -->
    </application>
</manifest>
```
> FileProvider во форке использует `applicationId` + суффикс плагина. Если меняете `applicationId`, синхронизируйте с FileProvider (форк уже настроен под текущий `applicationId`).

### 3.2 Gradle (`android/app/build.gradle.kts`)
Главное:
```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.zm_apps_webview_android"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.example.zm_apps_webview_android"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
}
```

### 3.3 Firebase
- Положите `android/app/google-services.json`.
- Используется Realtime Database (для `stray`/`swap`) и FCM (`fcm_token`).

### 3.4 AppsFlyer
В `lib/logic.dart` задайте:
```dart
const _appsflyerDevKey = '<your-dev-key>';
const _appsflyerAppId = '<your-ios-app-id-or-empty-for-android>';
```
Без ключа `appsflyer_id` будет `n/a`.

### 3.5 Кастомный file chooser (Android)
- Локальный форк `flutter_inappwebview_android` (см. `dependency_overrides`).
- Ключевой файл: `third_party/flutter_inappwebview_android/android/src/main/java/com/pichillilorenzo/flutter_inappwebview_android/webview/in_app_webview/InAppWebViewChromeClient.java`
  - `getOutputUri` для Android 10+ создаёт запись в MediaStore с именами `image-<timestamp>.jpg`, `video-<timestamp>.mp4`, чтобы `<input type="file">` видел имя после съёмки.
  - Для старых SDK — FileProvider.
- При переносе оставляйте форк как есть.

### 3.6 Рантайм-права
В `lib/webview.dart` запрашиваются: камера, микрофон, фото, видео, storage, notifications. `androidOnPermissionRequest` автоматически разрешает ресурсы в WebView.

---

## 4) Логика старта (`lib/logic.dart`)
1. Тянем конфиг из Firebase RTDB: `https://crazy-levelup-default-rtdb.firebaseio.com/.json`
   - Ожидаются ключи `stray` и `swap`. Если их нет — кэшируем `passed=false` и выходим без POST.
2. Собираем endpoint: `https://<stray><swap>`.
3. Собираем payload:
   - `adv_id` (`advertising_id`)
   - `fcm_token` (`firebase_messaging`)
   - `install_referrer` (`install_referrer`)
   - `os` (`device_info_plus`)
   - `gaid` (локальный UUID, кэшируется)
   - `appsflyer_id` (если задан dev key)
   - `flag` = 0
4. POST → если `passed=true` и `link` не пустой — открываем WebView, иначе показываем заглушку.
5. Кэшируем результат, чтобы не дёргать сервер повторно.
6. Логи: `[StartupRepository]` в logcat (кэш, payload JSON, ответы).

---

## 5) WebView (`lib/webview.dart`)
- `flutter_inappwebview`:
  - JS включён, multiple windows (`window.open`), pop-up стек.
  - allowFileAccess / allowContentAccess = true.
  - Внешние схемы (tg://, wa.me, intent:// и т.п.) открываются через `url_launcher`, внутренние (http/https/about/srcdoc/blob/data/javascript/file) остаются внутри.
  - Back: закрывает попап, потом `goBack`, потом выход.
- Разрешения запрашиваются при `initState`.

---

## 6) Запуск
```bash
flutter pub get
flutter run
```
При первом старте согласитесь на права (уведомления, камера/микрофон/хранилище).

---

## 7) Ключевые файлы
- Стартап и payload: `lib/logic.dart`
- Маршруты/заглушка/WebView: `lib/main.dart`, `lib/webview.dart`
- Манифест/права: `android/app/src/main/AndroidManifest.xml`
- Gradle: `android/app/build.gradle.kts`
- Форк WebView платформы (chooser): `third_party/flutter_inappwebview_android/.../InAppWebViewChromeClient.java`
- Override зависимостей: `pubspec.yaml`

---

## 8) Чек-лист для переноса в другой проект
- Скопировать `lib/` и `third_party/flutter_inappwebview_android`.
- Добавить `dependency_overrides` в `pubspec.yaml`.
- Положить `google-services.json` и настроить Firebase RTDB + FCM.
- Обновить AppsFlyer ключи (если нужны реальные ID).
- Проверить permissions и `usesCleartextTraffic` в манифесте.
- Собрать и протестировать загрузку файла: фото/видео должны отображать имя в `<input type="file">`.
