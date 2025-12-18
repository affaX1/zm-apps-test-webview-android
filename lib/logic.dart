import 'dart:async';
import 'dart:convert';
import 'package:advertising_id/advertising_id.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:install_referrer/install_referrer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _fallbackConfigUrl =
    'https://crazy-levelup-default-rtdb.firebaseio.com/.json';
const _cacheKey = 'startup_response_cache_v1';
const _linkHeadKey = 'stray'; // can change server-side; surfaced for easy edits
const _linkTailKey = 'swap'; // can change server-side; surfaced for easy edits
const _gaidCacheKey = 'gaid_cache_v1';
const _appsflyerDevKey =
    'p4BpJtUybxYwAQpopNyDK8'; // TODO: set your AppsFlyer dev key for real ID collection
const _appsflyerAppId =
    ''; // iOS app id (digits only); keep empty for Android-only builds

class StartupResult {
  final Uri? link;
  final String message;
  final bool passed;
  final bool fromCache;

  const StartupResult({
    required this.link,
    required this.message,
    required this.passed,
    required this.fromCache,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'link': link?.toString(),
        'message': message,
        'passed': passed,
      };

  static StartupResult fromJson(
    Map<String, dynamic> json, {
    required bool fromCache,
  }) {
    final rawLink = json['link'];
    return StartupResult(
      link: rawLink is String ? Uri.tryParse(rawLink) : null,
      message: json['message'] as String? ?? '',
      passed: json['passed'] as bool? ?? false,
      fromCache: fromCache,
    );
  }
}

class _LinkParts {
  final String head;
  final String tail;

  const _LinkParts({required this.head, required this.tail});

  Uri buildUri() => Uri.parse('https://${head.trim()}${tail.trim()}');
}

class StartupRepository {
  final http.Client _httpClient;

  StartupRepository({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  Future<StartupResult> loadOrRestore() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    print('[StartupRepository] Checking cached startup result');

    final String? cached = prefs.getString(_cacheKey);
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        print('[StartupRepository] Loaded cached result: $decoded');
        return StartupResult.fromJson(decoded, fromCache: true);
      } catch (_) {}
    }

    print('[StartupRepository] No cache found, fetching config');
    final Map<String, dynamic> config = await _fetchRemoteConfig();

    final _LinkParts? parts = _tryParseLinkParts(config);
    if (parts == null) {
      final StartupResult blocked = StartupResult(
        link: null,
        message:
            'Config missing expected keys: "$_linkHeadKey" & "$_linkTailKey"',
        passed: false,
        fromCache: false,
      );
      await prefs.setString(_cacheKey, jsonEncode(blocked.toJson()));
      return blocked;
    }
    final Uri endpoint = parts.buildUri();
    print('[StartupRepository] Built endpoint: $endpoint');
    final Map<String, dynamic> payload = await _buildPayload();
    print('[StartupRepository] Built payload: $payload');
    try {
      print('[StartupRepository] Payload JSON: ${jsonEncode(payload)}');
    } catch (_) {}
    final StartupResult freshResult =
        await _sendHandshake(endpoint: endpoint, payload: payload);

    await prefs.setString(_cacheKey, jsonEncode(freshResult.toJson()));
    print('[StartupRepository] Cached fresh result: ${freshResult.toJson()}');
    return freshResult;
  }

  Future<Map<String, dynamic>> _fetchRemoteConfig() async {
    try {
      final http.Response response = await _httpClient.get(
        Uri.parse(_fallbackConfigUrl),
      );
      print(
        '[StartupRepository] Link parts status: ${response.statusCode}, body: ${response.body}',
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    throw StateError('No link parts found in response');
  }

  _LinkParts? _tryParseLinkParts(Map<String, dynamic> data) {
    final String? head = _stringValue(data[_linkHeadKey]);
    final String? tail = _stringValue(data[_linkTailKey]);
    if (head == null || tail == null) return null;
    return _LinkParts(head: head, tail: tail);
  }

  String? _stringValue(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  Future<Map<String, dynamic>> _buildPayload() async {
    final List<dynamic> collected = await Future.wait<dynamic>([
      _getAdvertisingId().then((v) => _logField('adv_id', v)),
      _getFcmToken().then((v) => _logField('fcm_token', v)),
      _getInstallReferrer().then((v) => _logField('install_referrer', v)),
      _getOsVersion().then((v) => _logField('os', v)),
      _getOrCreateGaid().then((v) => _logField('gaid', v)),
      _getAppsFlyerId().then((v) => _logField('appsflyer_id', v)),
    ]);

    return <String, dynamic>{
      'adv_id': collected[0] as String? ?? 'n/a',
      'fcm_token': collected[1] as String? ?? 'n/a',
      'install_referrer': collected[2] as String? ?? 'n/a',
      'os': collected[3] as String? ?? 'n/a',
      'gaid': collected[4] as String? ?? 'n/a',
      'appsflyer_id': collected[5] as String? ?? 'n/a',
      'flag': 0,
    };
  }

  T _logField<T>(String key, T value) {
    final String display =
        value == null ? 'null' : (value.toString().isEmpty ? '<empty>' : '$value');
    print('[StartupRepository] collected $key: $display');
    return value;
  }

  Future<String?> _getAdvertisingId() async {
    try {
      final String? id = await AdvertisingId.id(true);
      return id?.trim().isNotEmpty == true ? id : null;
    } catch (error) {
      print('[StartupRepository] adv_id error: $error');
      return null;
    }
  }

  Future<String?> _getFcmToken() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      final String? token = await FirebaseMessaging.instance.getToken();
      return token?.trim().isNotEmpty == true ? token : null;
    } catch (error) {
      print('[StartupRepository] fcm_token error: $error');
      return null;
    }
  }

  Future<String?> _getInstallReferrer() async {
    try {
      final InstallationApp app = await InstallReferrer.app;
      final String referrer = app.referrer.toString().split('.').last;
      final String? packageName = app.packageName;
      if (packageName != null && packageName.isNotEmpty) {
        return 'ref=$referrer;pkg=$packageName';
      }
      return referrer;
    } catch (error) {
      print('[StartupRepository] install_referrer error: $error');
      return null;
    }
  }

  Future<String?> _getOsVersion() async {
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final android = await deviceInfo.androidInfo;
      return android.version.release ?? android.version.sdkInt.toString();
    } catch (error) {
      print('[StartupRepository] os version error: $error');
      return null;
    }
  }

  Future<String> _getOrCreateGaid() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? existing = prefs.getString(_gaidCacheKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final String generated = const Uuid().v4();
    await prefs.setString(_gaidCacheKey, generated);
    return generated;
  }

  Future<String?> _getAppsFlyerId() async {
    if (_appsflyerDevKey.isEmpty) {
      print('[StartupRepository] AppsFlyer dev key missing; skipping');
      return null;
    }
    try {
      final AppsflyerSdk sdk = AppsflyerSdk(
        AppsFlyerOptions(
          afDevKey: _appsflyerDevKey,
          appId: _appsflyerAppId,
          showDebug: true,
        ),
      );
      await sdk.initSdk();
      return await sdk.getAppsFlyerUID();
    } catch (error) {
      print('[StartupRepository] appsflyer_id error: $error');
      return null;
    }
  }

  Future<StartupResult> _sendHandshake({
    required Uri endpoint,
    required Map<String, dynamic> payload,
  }) async {
    try {
      print('[StartupRepository] Sending POST to $endpoint');
      final http.Response response = await _httpClient.post(
        endpoint,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      print(
        '[StartupRepository] Handshake status: ${response.statusCode}, body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        final Uri? link =
            data['link'] is String ? Uri.tryParse(data['link'] as String) : null;
        final bool passed = data['passed'] as bool? ?? false;
        final String message = data['message'] as String? ?? '';

        return StartupResult(
          link: link,
          message: message,
          passed: passed,
          fromCache: false,
        );
      }

      return StartupResult(
        link: null,
        message: 'Unexpected status ${response.statusCode}',
        passed: false,
        fromCache: false,
      );
    } catch (error) {
      return StartupResult(
        link: null,
        message: 'Request failed: $error',
        passed: false,
        fromCache: false,
      );
    }
  }
}

Future<StartupResult> initializeApp() async {
  try {
    await Firebase.initializeApp();
    print('[StartupRepository] Firebase initialized');
  } catch (error) {
    print('[StartupRepository] Firebase init error: $error');
  }
  final StartupRepository repository = StartupRepository();
  return repository.loadOrRestore();
}
