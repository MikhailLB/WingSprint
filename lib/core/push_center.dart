import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../env/runtime_config.dart';
import 'agent_client.dart';
import 'vault.dart';

// ============================================================
// PUSH CENTER — Firebase Messaging + local presentation
// ============================================================
// Token acquisition, foreground display (with big-picture support),
// and the cold/warm tap routing split:
//
//   killed  → getInitialMessage() → STASH url (BootGate consumes it)
//   warm bg → onMessageOpenedApp  → deliver via callback (one-shot)
//   fg      → onMessage → local notif → tap → deliver via callback
//
// The notification icon is the monochrome flame at
// @drawable/ic_spark_notify (distinct from the launcher icon).
//
// If Firebase config is absent (supplied later) every step fails
// silently and the app keeps working without push.
// ============================================================

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  // OS draws the tray notification; the tap is handled on resume.
}

const String _flameIcon = '@drawable/ic_spark_notify';

class PushCenter {
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final Vault _vault;

  FirebaseMessaging? _messaging;
  String? _token;
  bool _ready = false;

  /// Fired when a warm tap (background/foreground) carries a URL.
  /// PortalStage swaps this URL into the live WebView. Never persisted.
  void Function(String url)? onLiveUrl;

  /// Fired when FCM rotates the token (re-POST to gateway).
  void Function(String token)? onTokenRotated;

  PushCenter(this._vault);

  String? get token => _token;

  Future<void> boot() async {
    if (_ready) return;
    try {
      await Firebase.initializeApp();
      _messaging = FirebaseMessaging.instance;

      FirebaseMessaging.onBackgroundMessage(_bgHandler);
      await _setupLocal();

      _token = await _messaging!.getToken();
      _messaging!.onTokenRefresh.listen((t) {
        _token = t;
        onTokenRotated?.call(t);
      });

      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_onWarmTap);

      final cold = await _messaging!.getInitialMessage();
      if (cold != null) _onColdTap(cold);

      _ready = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[PushCenter] boot skipped: $e');
    }
  }

  Future<void> _setupLocal() async {
    const android = AndroidInitializationSettings(_flameIcon);
    const apple = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      const InitializationSettings(android: android, iOS: apple),
      onDidReceiveNotificationResponse: (resp) {
        final url = _urlFromPayload(resp.payload);
        if (url != null) onLiveUrl?.call(url);
      },
    );

    if (Platform.isAndroid) {
      final android = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          RuntimeConfig.alertChannelId,
          RuntimeConfig.alertChannelName,
          description: 'Delivery and offer alerts',
          importance: Importance.high,
        ),
      );
    }
  }

  /// Triggers the OS permission dialog (Android 13+) and records the
  /// outcome. A hard "denied" is remembered so the invite screen never
  /// pesters the user with a button that can no longer do anything.
  Future<bool> askPermission() async {
    final messaging = _messaging;
    if (messaging == null) return false;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final status = settings.authorizationStatus;
    final granted = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;

    await _vault.markInviteGranted(granted);
    if (status == AuthorizationStatus.denied) {
      await _vault.markInviteHardDenied();
    }
    return granted;
  }

  void _onForeground(RemoteMessage message) async {
    if (!Platform.isAndroid) return;
    final notif = message.notification;
    if (notif == null) return;

    final imageUrl = notif.android?.imageUrl;
    AndroidNotificationDetails details;

    final picture =
        (imageUrl != null && imageUrl.isNotEmpty) ? await _fetch(imageUrl) : null;
    if (picture != null) {
      details = AndroidNotificationDetails(
        RuntimeConfig.alertChannelId,
        RuntimeConfig.alertChannelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: _flameIcon,
        styleInformation: BigPictureStyleInformation(
          ByteArrayAndroidBitmap(picture),
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
      );
    } else {
      details = const AndroidNotificationDetails(
        RuntimeConfig.alertChannelId,
        RuntimeConfig.alertChannelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: _flameIcon,
      );
    }

    await _local.show(
      notif.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(android: details),
      payload: message.data.isEmpty ? null : jsonEncode(message.data),
    );
  }

  void _onColdTap(RemoteMessage message) {
    final url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) _vault.stashFlashUrl(url);
  }

  void _onWarmTap(RemoteMessage message) {
    final url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) onLiveUrl?.call(url);
  }

  String? _urlFromPayload(String? payload) {
    if (payload == null) return null;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final url = map['url'] as String?;
      if (url != null && url.isNotEmpty) return url;
    } catch (_) {}
    return null;
  }

  Future<Uint8List?> _fetch(String url) async {
    try {
      final res = await agentClient
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return res.bodyBytes;
    } catch (_) {}
    return null;
  }
}
