// ignore_for_file: avoid_print

// ============================================================
// MAKE ADAPTIVE FG — foreground layer for the Android adaptive icon
// ============================================================
// Android adaptive icons display a "safe zone" (official guidance: keep
// critical content within a centred ~66dp circle inside the 108dp
// canvas, i.e. roughly 61 % of the canvas diameter — about 19-20 %
// margin on every side) inside a 108×108dp canvas. Content outside that
// zone gets clipped differently by every launcher's mask shape (circle,
// squircle, rounded square, …).
//
// The source artwork is a full-bleed design (flames/labels touch every
// edge with no built-in margin), so it needs a sizeable transparent
// border added here — NOT the small ~12 % used for icons that already
// have breathing room — or the corner labels get chopped hard by a
// circular mask.
//
//   dart run tool/make_adaptive_fg.dart
//
// Output: assets/icon2_fg.png  (used by flutter_launcher_icons as
// adaptive_icon_foreground in pubspec.yaml)
// ============================================================

import 'dart:io';
import 'package:image/image.dart' as img;

// Border as a fraction of the source icon's dimension.
// 10 % of the source: the icon already has natural dark margins
// around the centred chicken, so a small border is enough to stay
// within the safe zone without making the subject look too small.
const double _borderFraction = 0.10;

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
