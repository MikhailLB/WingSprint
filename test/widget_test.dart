import 'package:flutter_test/flutter_test.dart';

import 'package:wing_sprint/game/models.dart';

void main() {
  test('level config scales difficulty with level', () {
    final l1 = LevelConfig.forLevel(1);
    final l9 = LevelConfig.forLevel(9);
    expect(l9.requiredEggs, greaterThan(l1.requiredEggs));
    expect(l9.foxes + l9.dogs, greaterThanOrEqualTo(l1.foxes + l1.dogs));
    expect(l9.enemySpeed, greaterThanOrEqualTo(l1.enemySpeed));
    expect(l1.cols, inInclusiveRange(7, 9));
  });

  test('loadout reflects upgrade tiers', () {
    final base = Loadout.fromTiers({});
    final maxed = Loadout.fromTiers({
      UpgradeType.basket: 4,
      UpgradeType.lives: 3,
      UpgradeType.speed: 3,
    });
    expect(base.basketCapacity, 3);
    expect(maxed.basketCapacity, 8);
    expect(maxed.startLives, 6);
    expect(maxed.speedMultiplier, greaterThan(base.speedMultiplier));
  });
}
