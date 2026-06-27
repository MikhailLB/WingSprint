import 'dart:math';
import 'models.dart';

enum GameState { playing, paused, levelComplete, gameOver }

enum TileType { grass, obstacleWater, obstacleGarden, coop, farm }

enum Facing { front, left, right }

/// A grid actor that glides smoothly cell-to-cell. [cx]/[cy] is the cell it is
/// leaving, [progress] is how far (0..1) it has travelled toward
/// (cx+dirX, cy+dirY). Integer arrival points are decision moments.
class Actor {
  int cx;
  int cy;
  int dirX = 0;
  int dirY = 0;
  double progress = 0;
  double speed; // cells per second

  Actor(this.cx, this.cy, this.speed);

  double get fx => cx + dirX * progress;
  double get fy => cy + dirY * progress;
  bool get moving => dirX != 0 || dirY != 0;

  Facing get facing {
    if (dirX < 0) return Facing.left;
    if (dirX > 0) return Facing.right;
    return Facing.front;
  }
}

class FieldEgg {
  int cx;
  int cy;
  FieldEgg(this.cx, this.cy);
}

/// Short-lived visual: a broken egg splat or a floating "+N" coin popup.
class Effect {
  final double x; // cell coords
  final double y;
  double life;
  final double maxLife;
  final bool isCoin;
  final int amount;
  Effect(this.x, this.y, this.maxLife, {this.isCoin = false, this.amount = 0})
      : life = maxLife;
}

class Enemy {
  final Actor actor;
  final bool isDog; // dog = chaser, fox = wanderer
  Enemy(this.actor, this.isDog);
}

class GameEngine {
  final Random _rng = gameRng;

  // ── viewport / rendering geometry (set by the widget) ──
  double tileSize = 0;
  double boardLeft = 0;
  double boardTop = 0;

  // ── level config + loadout ──
  late LevelConfig config;
  late Loadout loadout;

  GameState state = GameState.playing;

  // grid
  int cols = 7;
  int rows = 9;
  late List<List<TileType>> tiles;
  late Point<int> coopCell;
  late Point<int> farmCell;

  // actors
  late Actor chicken;
  final List<Enemy> enemies = [];
  final List<FieldEgg> fieldEggs = [];
  final List<Effect> effects = [];

  // run stats
  int carrying = 0;
  int delivered = 0;
  int lives = 3;
  int runCoins = 0;
  double timeLeft = 60;
  double invuln = 0;
  double menuTime = 0;
  double shakeTime = 0;

  int facingDirX = 0; // last horizontal input, for chicken sprite flip

  int get capacity => loadout.basketCapacity;
  int get requiredEggs => config.requiredEggs;
  bool get shielded => invuln > 0;

  void setViewport(double w, double h) {
    if (cols == 0 || rows == 0) return;
    final ts = min(w / cols, h / rows);
    tileSize = ts;
    boardLeft = (w - ts * cols) / 2;
    boardTop = (h - ts * rows) / 2;
  }

  void startLevel(LevelConfig cfg, Loadout lo) {
    config = cfg;
    loadout = lo;
    cols = cfg.cols;
    rows = cfg.rows;
    state = GameState.playing;
    carrying = 0;
    delivered = 0;
    runCoins = 0;
    lives = lo.startLives;
    timeLeft = cfg.dayTime;
    invuln = lo.shieldSeconds;
    shakeTime = 0;
    effects.clear();
    enemies.clear();
    fieldEggs.clear();

    _buildField();
    _spawnEnemies();
    for (int i = 0; i < cfg.eggsOnField; i++) {
      _spawnFieldEgg();
    }
  }

  // ── field generation ──

  void _buildField() {
    tiles = List.generate(
        rows, (_) => List.filled(cols, TileType.grass, growable: false));

    coopCell = Point(1, rows - 2);
    farmCell = Point(cols - 2, 1);
    tiles[coopCell.y][coopCell.x] = TileType.coop;
    tiles[farmCell.y][farmCell.x] = TileType.farm;

    // Scatter impassable obstacles, then guarantee a coop→farm path exists.
    int placed = 0;
    int attempts = 0;
    while (placed < config.obstacles && attempts < config.obstacles * 12) {
      attempts++;
      final x = _rng.nextInt(cols);
      final y = _rng.nextInt(rows);
      if (tiles[y][x] != TileType.grass) continue;
      // keep a breathing ring around coop/farm so they aren't walled in
      if (_near(x, y, coopCell) || _near(x, y, farmCell)) continue;
      final type =
          _rng.nextBool() ? TileType.obstacleWater : TileType.obstacleGarden;
      tiles[y][x] = type;
      if (!_pathExists(coopCell, farmCell)) {
        tiles[y][x] = TileType.grass; // would trap the player → revert
      } else {
        placed++;
      }
    }

    chicken = Actor(coopCell.x, coopCell.y, 4.6 * loadout.speedMultiplier);
    carrying = 0;
  }

  bool _near(int x, int y, Point<int> c) =>
      (x - c.x).abs() <= 1 && (y - c.y).abs() <= 1;

  bool walkable(int x, int y) {
    if (x < 0 || y < 0 || x >= cols || y >= rows) return false;
    final t = tiles[y][x];
    return t != TileType.obstacleWater && t != TileType.obstacleGarden;
  }

  bool _pathExists(Point<int> from, Point<int> to) {
    final visited = <int>{};
    final queue = <Point<int>>[from];
    int key(int x, int y) => y * cols + x;
    visited.add(key(from.x, from.y));
    while (queue.isNotEmpty) {
      final p = queue.removeLast();
      if (p == to) return true;
      for (final d in _dirs) {
        final nx = p.x + d[0];
        final ny = p.y + d[1];
        if (!walkable(nx, ny)) continue;
        if (visited.add(key(nx, ny))) queue.add(Point(nx, ny));
      }
    }
    return false;
  }

  static const _dirs = [
    [1, 0],
    [-1, 0],
    [0, 1],
    [0, -1],
  ];

  void _spawnEnemies() {
    void addEnemy(bool isDog, double speed) {
      Point<int>? cell;
      for (int t = 0; t < 60; t++) {
        final x = _rng.nextInt(cols);
        final y = _rng.nextInt(rows);
        if (!walkable(x, y)) continue;
        // spawn away from the coop so the player gets a moment to breathe
        if ((x - coopCell.x).abs() + (y - coopCell.y).abs() < 4) continue;
        cell = Point(x, y);
        break;
      }
      cell ??= farmCell;
      enemies.add(Enemy(Actor(cell.x, cell.y, speed), isDog));
    }

    final base = config.enemySpeed * loadout.enemySlowFactor;
    for (int i = 0; i < config.foxes; i++) {
      addEnemy(false, base);
    }
    for (int i = 0; i < config.dogs; i++) {
      addEnemy(true, base * 0.9);
    }
  }

  void _spawnFieldEgg() {
    for (int t = 0; t < 60; t++) {
      final x = _rng.nextInt(cols);
      final y = _rng.nextInt(rows);
      if (!walkable(x, y)) continue;
      if (tiles[y][x] == TileType.coop || tiles[y][x] == TileType.farm) {
        continue;
      }
      if (x == chicken.cx && y == chicken.cy) continue;
      if (fieldEggs.any((e) => e.cx == x && e.cy == y)) continue;
      fieldEggs.add(FieldEgg(x, y));
      return;
    }
  }

  // ── input ──

  void setDirection(int dx, int dy) {
    if (state != GameState.playing) return;
    if (dx != 0) facingDirX = dx;

    // Allow instant reversal mid-cell for responsive controls.
    if (chicken.moving &&
        dx == -chicken.dirX &&
        dy == -chicken.dirY &&
        chicken.progress > 0) {
      chicken.cx += chicken.dirX;
      chicken.cy += chicken.dirY;
      chicken.dirX = dx;
      chicken.dirY = dy;
      chicken.progress = 1 - chicken.progress;
      return;
    }

    if (!chicken.moving) {
      if (walkable(chicken.cx + dx, chicken.cy + dy)) {
        chicken.dirX = dx;
        chicken.dirY = dy;
        chicken.progress = 0;
      }
      _pendingDirX = 0;
      _pendingDirY = 0;
    } else {
      _pendingDirX = dx;
      _pendingDirY = dy;
    }
  }

  int _pendingDirX = 0;
  int _pendingDirY = 0;

  void togglePause() {
    if (state == GameState.playing) {
      state = GameState.paused;
    } else if (state == GameState.paused) {
      state = GameState.playing;
    }
  }

  // ── update loop ──

  void update(double dt) {
    menuTime += dt;
    if (shakeTime > 0) shakeTime = max(0, shakeTime - dt);
    _updateEffects(dt);

    if (state != GameState.playing) return;

    if (invuln > 0) invuln = max(0, invuln - dt);

    timeLeft -= dt;
    if (timeLeft <= 0) {
      timeLeft = 0;
      _endRun(win: false);
      return;
    }

    _moveChicken(dt);
    for (final e in enemies) {
      _moveEnemy(e, dt);
    }
    _checkEnemyCollisions();
  }

  void _moveChicken(double dt) {
    final c = chicken;
    if (!c.moving) {
      // try to start moving in the pending direction
      if (_pendingDirX != 0 || _pendingDirY != 0) {
        if (walkable(c.cx + _pendingDirX, c.cy + _pendingDirY)) {
          c.dirX = _pendingDirX;
          c.dirY = _pendingDirY;
          c.progress = 0;
          _pendingDirX = 0;
          _pendingDirY = 0;
        }
      }
      _checkCellPickups();
      return;
    }

    c.progress += c.speed * dt;
    while (c.progress >= 1.0) {
      c.cx += c.dirX;
      c.cy += c.dirY;
      c.progress -= 1.0;
      _checkCellPickups();
      if (state != GameState.playing) return;

      // decide next direction at the cell center
      int ndx = c.dirX, ndy = c.dirY;
      if ((_pendingDirX != 0 || _pendingDirY != 0) &&
          walkable(c.cx + _pendingDirX, c.cy + _pendingDirY)) {
        ndx = _pendingDirX;
        ndy = _pendingDirY;
        _pendingDirX = 0;
        _pendingDirY = 0;
      }
      if (!walkable(c.cx + ndx, c.cy + ndy)) {
        c.dirX = 0;
        c.dirY = 0;
        c.progress = 0;
        return;
      }
      c.dirX = ndx;
      c.dirY = ndy;
    }
  }

  void _moveEnemy(Enemy e, double dt) {
    final a = e.actor;
    if (!a.moving) {
      _pickEnemyDir(e);
      if (!a.moving) return;
    }
    a.progress += a.speed * dt;
    while (a.progress >= 1.0) {
      a.cx += a.dirX;
      a.cy += a.dirY;
      a.progress -= 1.0;
      _pickEnemyDir(e);
      if (!a.moving) {
        a.progress = 0;
        return;
      }
    }
  }

  void _pickEnemyDir(Enemy e) {
    final a = e.actor;
    final options = <List<int>>[];
    for (final d in _dirs) {
      if (!walkable(a.cx + d[0], a.cy + d[1])) continue;
      final isReverse = d[0] == -a.dirX && d[1] == -a.dirY;
      if (isReverse) continue;
      options.add(d);
    }
    // dead end → allow reversing
    if (options.isEmpty) {
      for (final d in _dirs) {
        if (walkable(a.cx + d[0], a.cy + d[1])) options.add(d);
      }
    }
    if (options.isEmpty) {
      a.dirX = 0;
      a.dirY = 0;
      return;
    }

    final chase = e.isDog ? 0.75 : 0.32; // dogs hunt, foxes mostly wander
    List<int> chosen;
    if (_rng.nextDouble() < chase) {
      options.sort((d1, d2) {
        final m1 = (a.cx + d1[0] - chicken.cx).abs() +
            (a.cy + d1[1] - chicken.cy).abs();
        final m2 = (a.cx + d2[0] - chicken.cx).abs() +
            (a.cy + d2[1] - chicken.cy).abs();
        return m1.compareTo(m2);
      });
      chosen = options.first;
    } else {
      chosen = options[_rng.nextInt(options.length)];
    }
    a.dirX = chosen[0];
    a.dirY = chosen[1];
    a.progress = 0;
  }

  // ── pickups / delivery ──

  void _checkCellPickups() {
    final x = chicken.cx, y = chicken.cy;

    // loose bonus eggs
    final idx = fieldEggs.indexWhere((e) => e.cx == x && e.cy == y);
    if (idx != -1) {
      fieldEggs.removeAt(idx);
      final gain = (6 * loadout.coinMultiplier).round();
      runCoins += gain;
      effects.add(Effect(x.toDouble(), y.toDouble(), 0.9,
          isCoin: true, amount: gain));
      _spawnFieldEgg();
    }

    final t = tiles[y][x];
    if (t == TileType.coop) {
      if (carrying < capacity) carrying = capacity;
    } else if (t == TileType.farm) {
      if (carrying > 0) {
        delivered += carrying;
        final gain = (carrying * 5 * loadout.coinMultiplier).round();
        runCoins += gain;
        effects.add(Effect(x.toDouble(), y.toDouble(), 1.0,
            isCoin: true, amount: gain));
        carrying = 0;
        if (delivered >= requiredEggs) {
          _endRun(win: true);
        }
      }
    }
  }

  void _checkEnemyCollisions() {
    if (shielded) return;
    for (final e in enemies) {
      final dx = e.actor.fx - chicken.fx;
      final dy = e.actor.fy - chicken.fy;
      if (dx * dx + dy * dy < 0.55 * 0.55) {
        _hitByEnemy();
        return;
      }
    }
  }

  void _hitByEnemy() {
    shakeTime = 0.4;
    invuln = 1.6;
    if (carrying > 0) {
      effects.add(Effect(chicken.fx, chicken.fy, 1.1)); // broken egg splat
      carrying = 0;
    }
    lives--;
    if (lives <= 0) {
      lives = 0;
      _endRun(win: false);
    }
  }

  void _endRun({required bool win}) {
    if (win) {
      runCoins += config.baseReward;
      state = GameState.levelComplete;
    } else {
      state = GameState.gameOver;
    }
  }

  void _updateEffects(double dt) {
    for (final f in effects) {
      f.life -= dt;
    }
    effects.removeWhere((f) => f.life <= 0);
  }
}
