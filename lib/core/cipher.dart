import 'dart:typed_data';

// ============================================================
// CIPHER — position-mixed XOR string unmasker
// ============================================================
// Every sensitive literal (gateway endpoint, tracking dev key,
// messaging sender id, browser version fragments) is stored as an
// obfuscated int blob produced by `tool/seed_pack.dart` instead of a
// readable string. This keeps the partner domain out of `strings`/grep
// scans of the release binary.
//
// SCHEME (unique to this app — do NOT reuse across projects):
//   1. A short seed phrase feeds an FNV-1a hash, which seeds an
//      xorshift32 stream. The stream yields a 20-byte rolling mask.
//   2. reveal() un-masks each byte with `mask[i % 20]` AND a
//      position salt `(i & 0x3F)`. The position salt is what makes
//      this distinct from a plain repeating-key XOR.
//
// To rotate the obfuscation for a fresh build: change `_seed`, then
// re-run `dart run tool/seed_pack.dart` and paste the new blobs into
// the env/*.dart files.
// ============================================================

const String _seed = 'w1ng-spr1nt';

Uint8List _forgeMask() {
  // FNV-1a 32-bit over the seed bytes → deterministic starting state.
  var h = 0x811C9DC5;
  for (final unit in _seed.codeUnits) {
    h = (h ^ unit) & 0xFFFFFFFF;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }

  var state = h == 0 ? 0x9E3779B9 : h;
  final mask = Uint8List(20);
  for (var i = 0; i < mask.length; i++) {
    // xorshift32
    state ^= (state << 13) & 0xFFFFFFFF;
    state ^= state >> 17;
    state ^= (state << 5) & 0xFFFFFFFF;
    state &= 0xFFFFFFFF;
    mask[i] = (state >> 11) & 0xFF;
  }
  return mask;
}

final Uint8List _mask = _forgeMask();

/// Un-masks a [blob] produced by `tool/seed_pack.dart` into its
/// original UTF-8 string. Returns an empty string for an empty blob.
String reveal(List<int> blob) {
  if (blob.isEmpty) return '';
  final bytes = Uint8List(blob.length);
  for (var i = 0; i < blob.length; i++) {
    bytes[i] = (blob[i] ^ _mask[i % _mask.length] ^ (i & 0x3F)) & 0xFF;
  }
  return String.fromCharCodes(bytes);
}
