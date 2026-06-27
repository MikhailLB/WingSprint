import 'package:shared_preferences/shared_preferences.dart';
import '../game/models.dart';

/// Persists meta-progression: coins, purchased upgrade tiers,
/// highest unlocked level and best stats. Pure local storage.
class StorageService {
  late final SharedPreferences _prefs;

  static const _kCoins = 'ws_coins';
  static const _kLevel = 'ws_level';
  static const _kBestEggs = 'ws_best_eggs';
  static const _kUpgradePrefix = 'ws_upg_';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  int get coins => _prefs.getInt(_kCoins) ?? 0;
  Future<void> setCoins(int v) => _prefs.setInt(_kCoins, v < 0 ? 0 : v);

  /// Highest level the player has reached (1-based). Lets the player
  /// resume at their hardest cleared stage.
  int get level => _prefs.getInt(_kLevel) ?? 1;
  Future<void> setLevel(int v) => _prefs.setInt(_kLevel, v < 1 ? 1 : v);

  int get bestEggs => _prefs.getInt(_kBestEggs) ?? 0;
  Future<void> setBestEggs(int v) async {
    if (v > bestEggs) await _prefs.setInt(_kBestEggs, v);
  }

  int upgradeTier(UpgradeType type) =>
      _prefs.getInt('$_kUpgradePrefix${type.name}') ?? 0;

  Future<void> setUpgradeTier(UpgradeType type, int tier) =>
      _prefs.setInt('$_kUpgradePrefix${type.name}', tier);

  /// Snapshot of all upgrade tiers, used to build the active loadout.
  Map<UpgradeType, int> allUpgradeTiers() {
    return {for (final t in UpgradeType.values) t: upgradeTier(t)};
  }
}
