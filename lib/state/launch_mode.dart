// ============================================================
// LAUNCH MODE — persisted routing decision
// ============================================================
// `fresh`  — never routed yet (first launch / verdict pending)
// `web`    — backend routed this install into the portal (WebView)
// `native` — backend declined; this install plays the native game
//            forever (the decision is sticky on purpose).
// ============================================================

enum LaunchMode {
  fresh,
  web,
  native;

  static const _storeValues = {
    LaunchMode.fresh: 'fresh',
    LaunchMode.web: 'web',
    LaunchMode.native: 'native',
  };

  String get token => _storeValues[this]!;

  static LaunchMode decode(String? token) {
    for (final entry in _storeValues.entries) {
      if (entry.value == token) return entry.key;
    }
    return LaunchMode.fresh;
  }
}
