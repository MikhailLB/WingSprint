import 'dart:ui' as ui;
import 'package:flutter/services.dart';

/// Loads and holds all decoded images. Singleton so the splash screen can
/// preload once and the painter can read synchronously every frame.
class GameAssets {
  static final GameAssets _instance = GameAssets._();
  factory GameAssets() => _instance;
  GameAssets._();

  late ui.Image chickenSheet; // 2x2 grid of poses
  late ui.Image fox;
  late ui.Image dog;
  late ui.Image egg;
  late ui.Image eggBroke;
  late ui.Image bucket;
  late ui.Image farm;
  late ui.Image grass;
  late ui.Image grassDark;
  late ui.Image ground;
  late ui.Image water;
  late ui.Image garden;

  bool loaded = false;

  Future<void> loadAll() async {
    if (loaded) return;
    final results = await Future.wait([
      _load('assets/chicken_4_views.png'), // 0
      _load('assets/fox_asset.png'), // 1
      _load('assets/dog_asset.png'), // 2
      _load('assets/egg_asset.png'), // 3
      _load('assets/egg_broke_asset.png'), // 4
      _load('assets/bucket_asset.png'), // 5
      _load('assets/farm_asset.png'), // 6
      _load('assets/grass_asset.png'), // 7
      _load('assets/grass_dark_asset.png'), // 8
      _load('assets/ground_asset.png'), // 9
      _load('assets/water_asset.png'), // 10
      _load('assets/garden_asset.png'), // 11
    ]);
    chickenSheet = results[0];
    fox = results[1];
    dog = results[2];
    egg = results[3];
    eggBroke = results[4];
    bucket = results[5];
    farm = results[6];
    grass = results[7];
    grassDark = results[8];
    ground = results[9];
    water = results[10];
    garden = results[11];
    loaded = true;
  }

  // ── Chicken sprite-sheet quadrants ──
  // Sheet layout (2x2):
  //   TL: front, holding eggs (used for up/down/idle)
  //   TR: front with basket (unused alt)
  //   BL: side facing LEFT
  //   BR: side facing RIGHT
  Rect get _half => Rect.fromLTWH(
      0, 0, chickenSheet.width / 2, chickenSheet.height / 2);

  Rect chickenFront() => _half;
  Rect chickenLeft() => _half.translate(0, chickenSheet.height / 2);
  Rect chickenRight() =>
      _half.translate(chickenSheet.width / 2, chickenSheet.height / 2);

  Future<ui.Image> _load(String path) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
