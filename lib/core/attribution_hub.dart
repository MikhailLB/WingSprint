import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import '../env/runtime_config.dart';
import '../env/tracking_secrets.dart';
import 'agent_client.dart';

// ============================================================
// ATTRIBUTION HUB — AppsFlyer init, attribution & payload builder
// ============================================================
// Collects install attribution + deep-link data and assembles the
// POST body the gateway uses to route the install.
//
// FALSE-ORGANIC GUARD (critical): the SDK occasionally fires the first
// conversion callback with af_status == "Organic" for a genuinely paid
// install. When that happens we wait `organicRecheckDelay` then re-pull
// the true data from the GCD endpoint and prefer it.
//
// The raw attribution fields are forwarded to the gateway untouched —
// the backend depends on the full, unfiltered set.
// ============================================================

class AttributionHub {
  AppsflyerSdk? _sdk;

  Map<String, dynamic>? _conversion;
  Map<String, dynamic>? _deepLink;
  Map<String, dynamic>? _openAttribution;

  final Completer<Map<String, dynamic>> _conversionReady = Completer();
  final Completer<void> _deepLinkReady = Completer();

  bool _started = false;

  /// Builds AppsFlyer options, wires the three callbacks, and starts the SDK.
  /// Safe to call when the dev key is still empty — it simply won't attribute.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      final options = AppsFlyerOptions(
        afDevKey: RuntimeConfig.trackingKey,
        appId: RuntimeConfig.appleStoreId,
        showDebug: kDebugMode,
        timeToWaitForATTUserAuthorization: 10,
      );
      final sdk = AppsflyerSdk(options);
      _sdk = sdk;

      sdk.onInstallConversionData(_onConversion);
      sdk.onAppOpenAttribution(_onOpenAttribution);
      sdk.onDeepLinking(_onDeepLink);

      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[AttributionHub] start failed: $e');
      _settleConversion(const {});
      _settleDeepLink();
    }
  }

  void _onConversion(dynamic data) async {
    final payload = _extractPayload(data);
    final status = '${payload['af_status'] ?? ''}'.toLowerCase();

    if (status == 'organic') {
      await Future.delayed(RuntimeConfig.organicRecheckDelay);
      final refreshed = await _resync();
      _conversion = refreshed ?? payload;
    } else {
      _conversion = payload;
    }
    _settleConversion(_conversion!);
  }

  void _onOpenAttribution(dynamic data) {
    _openAttribution = _extractPayload(data);
  }

  void _onDeepLink(dynamic result) {
    try {
      if (result is DeepLinkResult && result.deepLink != null) {
        _deepLink = Map<String, dynamic>.from(
          result.deepLink!.clickEvent,
        );
      }
    } catch (_) {}
    _settleDeepLink();
  }

  Map<String, dynamic> _extractPayload(dynamic data) {
    if (data is Map) {
      final inner = data['payload'] ?? data['data'] ?? data;
      if (inner is Map) {
        return inner.map((k, v) => MapEntry('$k', v));
      }
    }
    return <String, dynamic>{};
  }

  /// GCD re-pull when the first callback was false-organic.
  Future<Map<String, dynamic>?> _resync() async {
    try {
      final uid = await deviceUid();
      if (uid == null) return null;
      final appId =
          Platform.isIOS ? RuntimeConfig.appleStoreId : RuntimeConfig.packageId;
      final endpoint = buildSyncEndpoint(appId, uid);
      if (endpoint.isEmpty) return null;

      final res = await agentClient
          .get(Uri.parse(endpoint))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry('$k', v));
        }
      }
    } catch (_) {}
    return null;
  }

  void _settleConversion(Map<String, dynamic> data) {
    if (!_conversionReady.isCompleted) _conversionReady.complete(data);
  }

  void _settleDeepLink() {
    if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
  }

  /// Waits for attribution up to [budget], returning {} on timeout.
  Future<Map<String, dynamic>> awaitAttribution(Duration budget) {
    return _conversionReady.future
        .timeout(budget, onTimeout: () => <String, dynamic>{});
  }

  Future<void> awaitDeepLink() {
    return _deepLinkReady.future
        .timeout(RuntimeConfig.deepLinkWait, onTimeout: () {});
  }

  Future<String?> deviceUid() async {
    try {
      return await _sdk?.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  /// Assembles the gateway POST body. Attribution fields first (as-is),
  /// then deep-link / open-attribution merged without overwriting, then
  /// the always-present device-side fields.
  Future<Map<String, dynamic>> buildPayload({
    required String locale,
    String? pushToken,
  }) async {
    final body = <String, dynamic>{};
    body.addAll(_conversion ?? const {});
    _deepLink?.forEach((k, v) => body.putIfAbsent(k, () => v));
    _openAttribution?.forEach((k, v) => body.putIfAbsent(k, () => v));

    body['af_id'] = await deviceUid() ?? '';
    body['bundle_id'] = RuntimeConfig.packageId;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = RuntimeConfig.storeRef;
    body['locale'] = locale;

    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    final sender = RuntimeConfig.messagingSender;
    if (sender.isNotEmpty) {
      body['firebase_project_id'] = sender;
    }

    if (kDebugMode) {
      debugPrint('[AttributionHub] payload: ${jsonEncode(body)}');
    }
    return body;
  }
}
