import '../core/cipher.dart';

// ============================================================
// TRACKING SECRETS — obfuscated attribution + messaging ids
// ============================================================
// AppsFlyer dev key, Firebase messaging sender id, and the GCD
// (Get Conversion Data) base URL used to re-resolve attribution when
// the first install callback reports a false "Organic".
//
// The dev key and sender id are SUPPLIED LATER — they stay empty
// until then, and the gray flow degrades gracefully (it still POSTs
// the device-side body to the gateway). Encode them with
// `dart run tool/seed_pack.dart` once received and paste below.
// ============================================================

// AppsFlyer dashboard → App Settings → Dev Key.
const List<int> _devKey = [
  82, 155, 176, 108, 21, 12, 103, 222, 19, 126, 42,
  148, 27, 48, 57, 190, 168, 140, 109, 171, 104, 155,
];

// Firebase Console → Project Settings → Project number.
const List<int> _senderId = [
  12, 239, 209, 61, 84, 84, 58, 186, 69, 60, 125, 145,
];

// "https://gcdsdk.appsflyer.com"
const List<int> _syncHost = [
  87, 172, 156, 123, 17, 89, 44, 166, 23, 103, 40, 213, 61, 104,
  36, 181, 183, 164, 68, 165, 71, 181, 153, 109, 80, 28, 112, 248,
];

// "/install_data/v4.0/"
const List<int> _syncPath = [
  16, 177, 134, 120, 22, 2, 111, 229, 47, 96,
  45, 210, 56, 44, 124, 224, 233, 228, 24,
];

/// AppsFlyer dev key (empty until provided).
String revealTrackingKey() => reveal(_devKey);

/// Firebase messaging sender id / project number (empty until provided).
String revealSenderId() => reveal(_senderId);

/// Builds the GCD lookup URL used to refresh attribution after a
/// false-organic first callback.
/// Shape: `<host><path>{appId}?devkey=<key>&device_id=<deviceId>`
String buildSyncEndpoint(String appId, String deviceId) {
  final host = reveal(_syncHost);
  if (host.isEmpty) return '';
  return '$host${reveal(_syncPath)}$appId'
      '?devkey=${revealTrackingKey()}&device_id=$deviceId';
}
