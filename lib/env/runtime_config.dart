import 'gateway_secrets.dart';
import 'tracking_secrets.dart';
import 'legal_links.dart';

// ============================================================
// RUNTIME CONFIG — single facade for app-level constants
// ============================================================
// All other layers read identity, endpoints and tunables from here
// rather than touching the obfuscated env files directly.
// ============================================================

class RuntimeConfig {
  RuntimeConfig._();

  /// Play Store package name — must match android applicationId.
  static const String packageId = 'com.wingsprint.wingsprintgame';

  /// Store identifier (same as packageId on Android).
  static const String storeRef = 'com.wingsprint.wingsprintgame';

  /// Display name used in notifications and the launcher.
  static const String displayName = 'Wing Sprint';

  /// iOS App Store numeric id — unused on Android.
  static const String appleStoreId = '';

  /// Notification channel id — must match the AndroidManifest meta-data
  /// and the channel created in PushCenter.
  static const String alertChannelId = 'ws_pulse_alerts';
  static const String alertChannelName = 'Wing Sprint Alerts';

  /// Gateway POST endpoint (decoded).
  static String get gatewayUrl => revealGatewayUrl();

  /// AppsFlyer dev key (decoded; empty until provided).
  static String get trackingKey => revealTrackingKey();

  /// Firebase messaging sender id (decoded; empty until provided).
  static String get messagingSender => revealSenderId();

  /// Public legal/support URLs.
  static String get privacyUrl => privacyNoticeUrl;
  static String get supportUrl => helpDeskUrl;
  static String get homeUrl => siteHomeUrl;

  /// How long a "Skip" on the push-invite screen suppresses it (3 days).
  static const Duration pushInviteCooldown = Duration(days: 3);

  /// Delay before re-resolving attribution after a false-organic callback.
  static const Duration organicRecheckDelay = Duration(seconds: 5);

  /// Attribution wait budgets.
  static const Duration freshAttributionWait = Duration(seconds: 30);
  static const Duration returningAttributionWait = Duration(seconds: 10);
  static const Duration deepLinkWait = Duration(seconds: 5);

  /// Gateway request timeout.
  static const Duration gatewayTimeout = Duration(seconds: 15);
}
