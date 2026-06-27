// ignore_for_file: avoid_print

// ============================================================
// SQUASH ART — recompress full-screen loading backgrounds
// ============================================================
// The portrait/landscape loading screens ship as multi-MB PNGs. They
// are opaque full-bleed art (BoxFit.cover), so a downscaled JPG is
// visually identical on a phone but a fraction of the size, which keeps
// the per-device download under the 30 MB budget.
//
//   dart run tool/squash_art.dart
//
// Game sprites are intentionally left untouched (they rely on alpha).
// ============================================================

import 'dart:io';
import 'package:image/image.dart' as img;

const int _maxEdge = 1600;
const int _quality = 86;

const List<List<String>> _jobs = [
  ['assets/Vertical_Loading_Screen.png', 'assets/Vertical_Loading_Screen.jpg'],
  ['assets/Horizontal_Loading_Screen.png', 'assets/Horizontal_Loading_Screen.jpg'],
];

void main() {
  for (final job in _jobs) {
    final src = File(job[0]);
    if (!src.existsSync()) {
      print('skip (missing): ${job[0]}');
      continue;
    }
    final decoded = img.decodeImage(src.readAsBytesSync());
    if (decoded == null) {
      print('skip (decode failed): ${job[0]}');
      continue;
    }

    img.Image out = decoded;
    final longEdge = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    if (longEdge > _maxEdge) {
      if (decoded.width >= decoded.height) {
        out = img.copyResize(decoded, width: _maxEdge);
      } else {
        out = img.copyResize(decoded, height: _maxEdge);
      }
    }

    final jpg = img.encodeJpg(out, quality: _quality);
    File(job[1]).writeAsBytesSync(jpg);
    final before = src.lengthSync();
    final after = jpg.length;
    print('${job[0]} ${(before / 1024).round()}KB '
        '→ ${job[1]} ${(after / 1024).round()}KB');
  }
}
