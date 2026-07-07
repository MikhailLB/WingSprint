// ignore_for_file: avoid_print

// ============================================================
// TRIM LOADING EDGES — shave a hairline border off loading art
// ============================================================
// The horizontal loading background has a faint few-pixel white
// fringe on its bottom/left/right edges (a resize/JPEG artifact from
// squash_art.dart). Since the image is shown full-bleed with
// BoxFit.cover, we can simply crop that sliver off — Flutter re-scales
// the slightly smaller source to fill the screen, so the fringe just
// disappears with no visible zoom.
//
//   dart run tool/trim_loading_edges.dart
// ============================================================

import 'dart:io';
import 'package:image/image.dart' as img;

// This tool is run incrementally against whatever is currently in
// assets/ (the original source PNG is gone — see squash_art.dart), so
// each run's trim stacks on top of prior runs. Bump only the side(s)
// that still show a fringe.
const int _trimSidePx = 0;
const int _trimBottomPx = 6;
const int _quality = 86;

void main() {
  const path = 'assets/Horizontal_Loading_Screen.jpg';
  final file = File(path);
  if (!file.existsSync()) {
    print('ERROR: $path not found.');
    exit(1);
  }

  final src = img.decodeImage(file.readAsBytesSync());
  if (src == null) {
    print('ERROR: could not decode $path');
    exit(1);
  }

  // Keep the top edge untouched — only bottom/left/right show the fringe.
  final cropped = img.copyCrop(
    src,
    x: _trimSidePx,
    y: 0,
    width: src.width - _trimSidePx * 2,
    height: src.height - _trimBottomPx,
  );

  file.writeAsBytesSync(img.encodeJpg(cropped, quality: _quality));
  print(
    'Trimmed $path: ${src.width}x${src.height} -> '
    '${cropped.width}x${cropped.height} '
    '(-${_trimSidePx}px L/R, -${_trimBottomPx}px B)',
  );
}
