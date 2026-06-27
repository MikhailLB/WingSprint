// ignore_for_file: avoid_print

// ============================================================
// MAKE ADAPTIVE FG — foreground layer for the Android adaptive icon
// ============================================================
// Android adaptive icons display a 72×72dp "safe zone" inside a
// 108×108dp canvas. Content outside the safe zone may be clipped by
// the launcher's mask shape (circle, squircle, rounded square, …).
//
// This tool adds a transparent border equal to ~12 % of the original
// icon's dimension on each side so the main subject (the chicken) stays
// within the safe zone without becoming too small.
//
//   dart run tool/make_adaptive_fg.dart
//
// Output: assets/icon2_fg.png  (used by flutter_launcher_icons as
// adaptive_icon_foreground in pubspec.yaml)
// ============================================================

import 'dart:io';
import 'package:image/image.dart' as img;

// Border as a fraction of the source icon's dimension.
// 12 % keeps the subject prominent while fitting the official safe zone.
const double _borderFraction = 0.12;

void main() {
  final srcFile = File('assets/icon2.png');
  if (!srcFile.existsSync()) {
    print('ERROR: assets/icon2.png not found. Run from project root.');
    exit(1);
  }

  final orig = img.decodeImage(srcFile.readAsBytesSync());
  if (orig == null) {
    print('ERROR: could not decode assets/icon2.png');
    exit(1);
  }

  final pad = (orig.width * _borderFraction).round();
  final canvas = img.Image(
    width: orig.width + pad * 2,
    height: orig.height + pad * 2,
    numChannels: 4,
  );

  // Transparent background so the adaptive_icon_background colour shows through.
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

  // Place original icon centred.
  img.compositeImage(canvas, orig, dstX: pad, dstY: pad);

  File('assets/icon2_fg.png').writeAsBytesSync(img.encodePng(canvas));
  print(
    'Done: assets/icon2_fg.png  ${canvas.width}×${canvas.height}px  '
    '(original: ${orig.width}×${orig.height}px, '
    'border: ${pad}px each side = ${(_borderFraction * 100).round()}%)',
  );
}
