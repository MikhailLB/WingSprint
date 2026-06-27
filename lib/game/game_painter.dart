import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'game_assets.dart';
import 'game_engine.dart';

class GamePainter extends CustomPainter {
  final GameEngine engine;
  final GameAssets assets;
  final Random _rng = Random();

  GamePainter({required this.engine, required this.assets})
      : super(repaint: null);

  @override
  void paint(Canvas canvas, Size size) {
    engine.setViewport(size.width, size.height);
    final ts = engine.tileSize;
    if (ts <= 0) return;

    double shx = 0, shy = 0;
    if (engine.shakeTime > 0) {
      final m = engine.shakeTime * 18;
      shx = (_rng.nextDouble() - 0.5) * m;
      shy = (_rng.nextDouble() - 0.5) * m;
    }
    canvas.save();
    canvas.translate(shx, shy);

    _drawField(canvas);
    _drawFieldEggs(canvas);
    _drawActors(canvas);
    _drawEffects(canvas);

    canvas.restore();
  }

  Offset _cellCenter(double fx, double fy) {
    return Offset(
      engine.boardLeft + (fx + 0.5) * engine.tileSize,
      engine.boardTop + (fy + 0.5) * engine.tileSize,
    );
  }

  void _drawField(Canvas canvas) {
    final ts = engine.tileSize;
    final boardRect = Rect.fromLTWH(
        engine.boardLeft, engine.boardTop, ts * engine.cols, ts * engine.rows);

    // soft ground backing + border frame
    final framePaint = Paint()..color = const Color(0xFF4E7A2A);
    canvas.drawRRect(
        RRect.fromRectAndRadius(boardRect.inflate(6), const Radius.circular(14)),
        framePaint);

    // grass texture: crop the asset border out and tile per cell
    final gw = assets.grass.width.toDouble();
    final gh = assets.grass.height.toDouble();
    final grassSrc = Rect.fromLTRB(gw * 0.12, gh * 0.12, gw * 0.88, gh * 0.88);

    final paint = Paint()..filterQuality = FilterQuality.low;
    for (int y = 0; y < engine.rows; y++) {
      for (int x = 0; x < engine.cols; x++) {
        final cell = Rect.fromLTWH(
            engine.boardLeft + x * ts, engine.boardTop + y * ts, ts + 0.5, ts + 0.5);
        canvas.drawImageRect(assets.grass, grassSrc, cell, paint);
      }
    }

    // faint cell grid for the "cell field" read
    final grid = Paint()
      ..color = Colors.black.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (int x = 1; x < engine.cols; x++) {
      final px = engine.boardLeft + x * ts;
      canvas.drawLine(Offset(px, boardRect.top), Offset(px, boardRect.bottom), grid);
    }
    for (int y = 1; y < engine.rows; y++) {
      final py = engine.boardTop + y * ts;
      canvas.drawLine(Offset(boardRect.left, py), Offset(boardRect.right, py), grid);
    }

    // special / obstacle tiles
    for (int y = 0; y < engine.rows; y++) {
      for (int x = 0; x < engine.cols; x++) {
        final t = engine.tiles[y][x];
        final center = _cellCenter(x.toDouble(), y.toDouble());
        switch (t) {
          case TileType.obstacleWater:
            _drawTileImageClipped(canvas, assets.water, center, ts * 0.98);
            break;
          case TileType.obstacleGarden:
            _drawTileImageClipped(canvas, assets.garden, center, ts * 0.98);
            break;
          case TileType.coop:
            _drawSprite(canvas, assets.bucket, center, ts * 0.92);
            break;
          case TileType.farm:
            _drawSprite(canvas, assets.farm, center.translate(0, -ts * 0.08),
                ts * 1.15);
            break;
          case TileType.grass:
            break;
        }
      }
    }
  }

  void _drawFieldEggs(Canvas canvas) {
    final bob = sin(engine.menuTime * 4) * engine.tileSize * 0.05;
    for (final e in engine.fieldEggs) {
      final c = _cellCenter(e.cx.toDouble(), e.cy.toDouble()).translate(0, bob);
      _drawSprite(canvas, assets.egg, c, engine.tileSize * 0.55);
    }
  }

  void _drawActors(Canvas canvas) {
    // enemies first so the chicken renders on top when overlapping
    for (final enemy in engine.enemies) {
      final a = enemy.actor;
      final hop = a.moving ? sin(a.progress * pi) * engine.tileSize * 0.08 : 0.0;
      final c = _cellCenter(a.fx, a.fy).translate(0, -hop);
      final img = enemy.isDog ? assets.dog : assets.fox;
      // fox sprite faces right, dog faces front; flip when heading left
      final flip = a.dirX < 0;
      _drawSprite(canvas, img, c, engine.tileSize * (enemy.isDog ? 1.0 : 1.05),
          flipX: flip);
    }

    // chicken
    final ch = engine.chicken;
    final hop = ch.moving ? sin(ch.progress * pi) * engine.tileSize * 0.12 : 0.0;
    final bob = !ch.moving ? sin(engine.menuTime * 6) * engine.tileSize * 0.03 : 0.0;
    final c = _cellCenter(ch.fx, ch.fy).translate(0, -hop + bob);

    ui.Image img = assets.chickenSheet;
    Rect src;
    bool flip = false;
    if (ch.dirX < 0) {
      src = assets.chickenLeft();
    } else if (ch.dirX > 0) {
      src = assets.chickenRight();
    } else {
      src = assets.chickenFront();
    }

    double opacity = 1.0;
    if (engine.shielded) {
      // blink while invulnerable; steady glow during the start shield
      opacity = (sin(engine.menuTime * 30) > 0) ? 1.0 : 0.45;
    }
    _drawSpriteSrc(canvas, img, src, c, engine.tileSize * 1.2,
        flipX: flip, opacity: opacity);

    if (engine.shielded) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0xFF26C6DA).withValues(alpha: 0.6);
      canvas.drawCircle(c, engine.tileSize * 0.62, ring);
    }
  }

  void _drawEffects(Canvas canvas) {
    for (final f in engine.effects) {
      final t = 1 - (f.life / f.maxLife); // 0..1 progress
      final center = _cellCenter(f.x, f.y);
      if (f.isCoin) {
        final dy = -engine.tileSize * 0.6 * t;
        _drawText(canvas, '+${f.amount}', center.translate(0, dy),
            color: const Color(0xFFFFD54F),
            size: engine.tileSize * 0.36,
            opacity: (1 - t).clamp(0.0, 1.0));
      } else {
        final scale = 0.7 + t * 0.5;
        _drawSprite(canvas, assets.eggBroke, center,
            engine.tileSize * 0.8 * scale,
            opacity: (1 - t).clamp(0.0, 1.0));
      }
    }
  }

  // ── draw helpers ──

  void _drawSprite(Canvas canvas, ui.Image img, Offset center, double size,
      {bool flipX = false, double opacity = 1.0}) {
    final src =
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    _drawSpriteSrc(canvas, img, src, center, size,
        flipX: flipX, opacity: opacity);
  }

  void _drawSpriteSrc(
      Canvas canvas, ui.Image img, Rect src, Offset center, double size,
      {bool flipX = false, double opacity = 1.0}) {
    final aspect = src.width / src.height;
    double w = size, h = size;
    if (aspect >= 1) {
      h = size / aspect;
    } else {
      w = size * aspect;
    }
    final dst = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Colors.white.withValues(alpha: opacity);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (flipX) canvas.scale(-1, 1);
    canvas.drawImageRect(img, src, dst, paint);
    canvas.restore();
  }

  void _drawTileImageClipped(
      Canvas canvas, ui.Image img, Offset center, double size) {
    final rect = Rect.fromCenter(center: center, width: size, height: size);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size * 0.18));
    canvas.save();
    canvas.clipRRect(rrect);
    final iw = img.width.toDouble();
    final ih = img.height.toDouble();
    final src = Rect.fromLTRB(iw * 0.1, ih * 0.1, iw * 0.9, ih * 0.9);
    canvas.drawImageRect(img, src, rect,
        Paint()..filterQuality = FilterQuality.medium);
    canvas.restore();
  }

  void _drawText(Canvas canvas, String text, Offset center,
      {required Color color, required double size, double opacity = 1.0}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.withValues(alpha: opacity),
          fontSize: size,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(
                color: Colors.black.withValues(alpha: opacity * 0.7),
                blurRadius: 3,
                offset: const Offset(0, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
