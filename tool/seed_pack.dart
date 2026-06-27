// ============================================================
// SEED PACK — secret obfuscator (run with `dart run`)
// ============================================================
// Produces the int blobs that the env/*.dart files feed into
// `reveal()` (see lib/core/cipher.dart). The masking logic here is a
// byte-for-byte copy of cipher.dart — keep the two in sync. If you
// change `_seed`, change it in BOTH files and re-run this tool.
//
//   dart run tool/seed_pack.dart
//
// ⚠️ Always use `dart run`. PowerShell foreach loops overflow 32-bit
//    ints on Windows and emit wrong bytes (symptom: HTTP 400 / bad
//    header value at runtime).
// ============================================================

// ignore_for_file: avoid_print

import 'dart:typed_data';

const String _seed = 'w1ng-spr1nt';

Uint8List _forgeMask() {
  var h = 0x811C9DC5;
  for (final unit in _seed.codeUnits) {
    h = (h ^ unit) & 0xFFFFFFFF;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  var state = h == 0 ? 0x9E3779B9 : h;
  final mask = Uint8List(20);
  for (var i = 0; i < mask.length; i++) {
    state ^= (state << 13) & 0xFFFFFFFF;
    state ^= state >> 17;
    state ^= (state << 5) & 0xFFFFFFFF;
    state &= 0xFFFFFFFF;
    mask[i] = (state >> 11) & 0xFF;
  }
  return mask;
}

final Uint8List _mask = _forgeMask();

List<int> _pack(String value) {
  final units = value.codeUnits;
  final out = List<int>.filled(units.length, 0);
  for (var i = 0; i < units.length; i++) {
    out[i] = (units[i] ^ _mask[i % _mask.length] ^ (i & 0x3F)) & 0xFF;
  }
  return out;
}

void _emit(String label, String value) {
  if (value.isEmpty) {
    print('// $label — EMPTY (fill in when provided)');
    print('const <int>[];\n');
    return;
  }
  final blob = _pack(value);
  print('// $label  ←  "$value"');
  print('const <int>[${blob.join(', ')}];\n');
}

void main() {
  // ---- gateway (config endpoint) ----
  _emit('gateway host', 'https://wiingsprint.com');
  _emit('gateway path', '/config.php');

  // ---- browser user-agent fragments ----
  _emit('chrome version', '126.0.6478.71');
  _emit('webkit version', '537.36');

  // ---- attribution sync (GCD) base, used once a dev key is provided ----
  _emit('sync host', 'https://gcdsdk.appsflyer.com');
  _emit('sync path', '/install_data/v4.0/');

  // ---- secrets ----
  // Already encoded into lib/env/tracking_secrets.dart. Re-enter the
  // plaintext values here only when rotating them, then paste the new
  // blobs back and clear these again (keep plaintext out of git).
  _emit('tracking dev key', '');
  _emit('messaging sender id', '');
}
