import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../env/runtime_config.dart';
import '../state/launch_mode.dart';

// ============================================================
// VAULT — persistence for the gray flow
// ============================================================
// Split storage: durable, non-secret flags live in SharedPreferences;
// the resolved portal URLs (the sensitive bit) live in encrypted
// secure storage.
//
// Key names are deliberately terse / neutral so a prefs dump doesn't
// telegraph intent.
// ============================================================

class Vault {
  // prefs keys
  static const _kMode = 'wsx.mode';
  static const _kExpiry = 'wsx.exp';
  static const _kInviteCooldownUntil = 'wsx.inv.until';
  static const _kInviteGranted = 'wsx.inv.ok';
  static const _kInviteHardDenied = 'wsx.inv.blocked';

  // secure keys
  static const _kPortalUrl = 'wsx_portal';
  static const _kFlashUrl = 'wsx_flash';

  late final SharedPreferences _prefs;
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<void> open() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ---- launch mode ----

  LaunchMode get mode => LaunchMode.decode(_prefs.getString(_kMode));

  Future<void> setMode(LaunchMode mode) =>
      _prefs.setString(_kMode, mode.token);

  // ---- cached portal url (secure) + expiry ----

  Future<String?> readPortalUrl() => _secure.read(key: _kPortalUrl);

  Future<void> writePortalUrl(String url) =>
      _secure.write(key: _kPortalUrl, value: url);

  Future<void> writeExpiry(int unixSeconds) =>
      _prefs.setInt(_kExpiry, unixSeconds);

  int? get expiry => _prefs.getInt(_kExpiry);

  bool get isPortalStale {
    final exp = expiry;
    if (exp == null) return true;
    return _nowSeconds() >= exp;
  }

  // ---- one-shot push url (secure) ----

  Future<void> stashFlashUrl(String? url) async {
    if (url == null || url.isEmpty) {
      await _secure.delete(key: _kFlashUrl);
    } else {
      await _secure.write(key: _kFlashUrl, value: url);
    }
  }

  /// Reads and clears the one-shot push URL in a single call.
  Future<String?> takeFlashUrl() async {
    final url = await _secure.read(key: _kFlashUrl);
    if (url != null) await _secure.delete(key: _kFlashUrl);
    return url;
  }

  // ---- push invite gating ----

  bool get inviteGranted => _prefs.getBool(_kInviteGranted) ?? false;
  Future<void> markInviteGranted(bool granted) =>
      _prefs.setBool(_kInviteGranted, granted);

  /// Set once the OS dialog is permanently dismissed (Android can't
  /// re-prompt). Without this flag the invite screen would reappear
  /// after the cooldown and the Accept button would do nothing.
  bool get inviteHardDenied => _prefs.getBool(_kInviteHardDenied) ?? false;
  Future<void> markInviteHardDenied() =>
      _prefs.setBool(_kInviteHardDenied, true);

  Future<void> snoozeInvite() {
    final until = _nowSeconds() +
        RuntimeConfig.pushInviteCooldown.inSeconds;
    return _prefs.setInt(_kInviteCooldownUntil, until);
  }

  /// Decides whether to show the push-invite promo before the portal.
  bool get shouldOfferInvite {
    if (inviteGranted) return false;
    if (inviteHardDenied) return false;
    final until = _prefs.getInt(_kInviteCooldownUntil);
    if (until == null) return true;
    return _nowSeconds() >= until;
  }

  static int _nowSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
