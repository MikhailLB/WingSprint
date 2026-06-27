import 'dart:math';
import 'package:flutter/material.dart';

// ============================================================
// UPGRADES (meta-progression / "прокачка")
// ============================================================

enum UpgradeType {
  basket, // egg-carrying capacity per trip
  speed, // chicken move speed
  lives, // starting lives
  slowEnemies, // global enemy speed reduction
  shield, // invincibility seconds at level start
  fortune, // coin multiplier on delivery
}

class UpgradeDef {
  final UpgradeType type;
  final String title;
  final String desc;
  final IconData icon;
  final Color color;

  /// Cost to buy each tier. Length == max tiers.
  final List<int> costs;

  /// Human-readable value shown for tier i (0 == base / not bought).
  final List<String> tierLabels;

  const UpgradeDef({
    required this.type,
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
    required this.costs,
    required this.tierLabels,
  });

  int get maxTier => costs.length;
}

const List<UpgradeDef> kUpgrades = [
  UpgradeDef(
    type: UpgradeType.basket,
    title: 'Basket',
    desc: 'Carry more eggs per trip',
    icon: Icons.shopping_basket,
    color: Color(0xFFC8873E),
    costs: [80, 200, 450, 900],
    tierLabels: ['3', '4', '5', '6', '8'],
  ),
  UpgradeDef(
    type: UpgradeType.speed,
    title: 'Fast Legs',
    desc: 'Run faster across the field',
    icon: Icons.bolt,
    color: Color(0xFF42A5F5),
    costs: [100, 260, 600],
    tierLabels: ['Normal', 'Quick', 'Swift', 'Turbo'],
  ),
  UpgradeDef(
    type: UpgradeType.lives,
    title: 'Spare Eggs',
    desc: 'Start with extra lives',
    icon: Icons.favorite,
    color: Color(0xFFEF5350),
    costs: [150, 400, 850],
    tierLabels: ['3', '4', '5', '6'],
  ),
  UpgradeDef(
    type: UpgradeType.slowEnemies,
    title: 'Calm Farm',
    desc: 'Foxes & dogs move slower',
    icon: Icons.pets,
    color: Color(0xFF7E57C2),
    costs: [120, 320, 700],
    tierLabels: ['0%', '12%', '22%', '32%'],
  ),
  UpgradeDef(
    type: UpgradeType.shield,
    title: 'Head Start',
    desc: 'Invincible at level start',
    icon: Icons.shield,
    color: Color(0xFF26A69A),
    costs: [110, 300, 650],
    tierLabels: ['0s', '2s', '4s', '6s'],
  ),
  UpgradeDef(
    type: UpgradeType.fortune,
    title: 'Lucky Hen',
    desc: 'More coins per delivery',
    icon: Icons.attach_money,
    color: Color(0xFFFFB300),
    costs: [200, 500, 1100],
    tierLabels: ['x1', 'x1.3', 'x1.6', 'x2'],
  ),
];

UpgradeDef upgradeDef(UpgradeType t) =>
    kUpgrades.firstWhere((u) => u.type == t);

/// Resolved gameplay stats derived from purchased upgrade tiers.
class Loadout {
  final int basketCapacity;
  final double speedMultiplier;
  final int startLives;
  final double enemySlowFactor; // multiply enemy speed by this
  final double shieldSeconds;
  final double coinMultiplier;

  const Loadout({
    required this.basketCapacity,
    required this.speedMultiplier,
    required this.startLives,
    required this.enemySlowFactor,
    required this.shieldSeconds,
    required this.coinMultiplier,
  });

  factory Loadout.fromTiers(Map<UpgradeType, int> tiers) {
    final basket = [3, 4, 5, 6, 8][(tiers[UpgradeType.basket] ?? 0).clamp(0, 4)];
    final speed = [1.0, 1.18, 1.36, 1.6][(tiers[UpgradeType.speed] ?? 0).clamp(0, 3)];
    final lives = [3, 4, 5, 6][(tiers[UpgradeType.lives] ?? 0).clamp(0, 3)];
    final slow = [1.0, 0.88, 0.78, 0.68][(tiers[UpgradeType.slowEnemies] ?? 0).clamp(0, 3)];
    final shield = [0.0, 2.0, 4.0, 6.0][(tiers[UpgradeType.shield] ?? 0).clamp(0, 3)];
    final fortune = [1.0, 1.3, 1.6, 2.0][(tiers[UpgradeType.fortune] ?? 0).clamp(0, 3)];
    return Loadout(
      basketCapacity: basket,
      speedMultiplier: speed,
      startLives: lives,
      enemySlowFactor: slow,
      shieldSeconds: shield,
      coinMultiplier: fortune,
    );
  }
}

// ============================================================
// LEVEL CONFIG (difficulty scaling / "усложнение по уровням")
// ============================================================

class LevelConfig {
  final int level;
  final int cols;
  final int rows;
  final int requiredEggs; // deliveries needed before day ends
  final int foxes;
  final int dogs;
  final double enemySpeed; // tiles per second
  final double dayTime; // seconds available
  final int obstacles; // impassable decoration tiles
  final int eggsOnField; // simultaneous pickups available

  const LevelConfig({
    required this.level,
    required this.cols,
    required this.rows,
    required this.requiredEggs,
    required this.foxes,
    required this.dogs,
    required this.enemySpeed,
    required this.dayTime,
    required this.obstacles,
    required this.eggsOnField,
  });

  /// Procedural difficulty curve. Grid grows (distance), enemies multiply
  /// and speed up, quota rises and the day shortens — but everything is
  /// clamped so even high levels stay readable on a phone screen.
  factory LevelConfig.forLevel(int level) {
    final l = level.clamp(1, 9999);
    final cols = (7 + (l ~/ 3)).clamp(7, 9);
    final rows = (9 + (l ~/ 2)).clamp(9, 15);
    final foxes = (1 + l ~/ 2).clamp(1, 6);
    final dogs = (l >= 3 ? (l - 1) ~/ 3 : 0).clamp(0, 4);
    final enemySpeed = (2.0 + l * 0.22).clamp(2.0, 5.0);
    final required = 3 + (l * 1.4).floor();
    final dayTime = (75.0 - l * 2.5).clamp(40.0, 75.0);
    final obstacles = (l * 1.5).floor().clamp(0, (cols * rows) ~/ 6);
    final eggsField = (3 + l ~/ 2).clamp(3, 6);
    return LevelConfig(
      level: l,
      cols: cols,
      rows: rows,
      requiredEggs: required,
      foxes: foxes,
      dogs: dogs,
      enemySpeed: enemySpeed,
      dayTime: dayTime,
      obstacles: obstacles,
      eggsOnField: eggsField,
    );
  }

  /// Reward for completing the level (before fortune multiplier).
  int get baseReward => 40 + level * 15;
}

/// Shared RNG helper so layout/spawn jitter is centralized.
final Random gameRng = Random();
