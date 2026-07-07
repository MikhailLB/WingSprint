import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../core/attribution_hub.dart';
import '../core/net_sensor.dart';
import '../core/push_center.dart';
import '../core/verdict_gateway.dart';
import '../core/vault.dart';
import '../env/runtime_config.dart';
import '../game/game_assets.dart';
import '../game/game_screen.dart';
import '../services/storage_service.dart';
import '../state/launch_mode.dart';
import 'offline_screen.dart';
import 'push_invite_screen.dart';
import 'portal_stage.dart' deferred as portal;

// ============================================================
// BOOT GATE — loading screen + web/native routing
// ============================================================
// Single entry surface. Shows the branded loader in BOTH orientations
// while it decides, per the persisted LaunchMode, whether to:
//   • LaunchMode.fresh  → run the full attribution → gateway handshake,
//                         then route web (portal) or native (game).
//   • LaunchMode.web    → re-check the gateway (URLs rotate), honour a
//                         one-shot push URL first, fall back to cache.
//   • LaunchMode.native → preload assets and open the game.
//
// The portal engine is a deferred import so organic (game) users never
// pay to load the WebView stack.
// ============================================================

class BootGate extends StatefulWidget {
  final Vault vault;
  final NetSensor net;
  final AttributionHub attribution;
  final VerdictGateway gateway;
  final PushCenter push;
  final StorageService gameStorage;

  const BootGate({
    super.key,
    required this.vault,
    required this.net,
    required this.attribution,
    required this.gateway,
    required this.push,
    required this.gameStorage,
  });

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _barCtrl;
  double _progress = 0.05;
  bool _handed = false;

  @override
  void initState() {
    super.initState();
    _barCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _drive();
  }

  @override
  void dispose() {
    widget.push.onTokenRotated = null;
    _barCtrl.dispose();
    super.dispose();
  }

  void _lift(double to) {
    if (!mounted) return;
    setState(() => _progress = to.clamp(0.0, 1.0));
  }

  String _locale() => Platform.localeName.replaceAll('-', '_');

  Future<void> _drive() async {
    widget.push.onTokenRotated = _onTokenRotated;
    await widget.push.boot();

    switch (widget.vault.mode) {
      case LaunchMode.web:
        await _runReturningWeb();
        break;
      case LaunchMode.native:
        await _runNative(quickBar: true);
        break;
      case LaunchMode.fresh:
        await _runFirstLaunch();
        break;
    }
  }

  void _onTokenRotated(String token) async {
    final payload = await widget.attribution.buildPayload(
      locale: _locale(),
      pushToken: token,
    );
    widget.gateway.resolve(payload);
  }

  Future<void> _runFirstLaunch() async {
    _lift(0.18);
    if (!await widget.net.isReachable()) {
      _toOffline();
      return;
    }

    _lift(0.4);
    await widget.attribution.start();
    await Future.wait([
      widget.attribution.awaitAttribution(RuntimeConfig.freshAttributionWait),
      widget.attribution.awaitDeepLink(),
    ]);
    _lift(0.7);

    final payload = await widget.attribution.buildPayload(
      locale: _locale(),
      pushToken: widget.push.token,
    );
    final verdict = await widget.gateway.resolve(payload);

    if (verdict.hasPortal) {
      await widget.vault.setMode(LaunchMode.web);
      _lift(1.0);
      await Future.delayed(const Duration(milliseconds: 360));
      await _toPortal(verdict.portalUrl!);
    } else {
      await widget.vault.setMode(LaunchMode.native);
      await GameAssets().loadAll();
      _lift(1.0);
      await Future.delayed(const Duration(milliseconds: 360));
      _toGame();
    }
  }

  Future<void> _runReturningWeb() async {
    _lift(0.3);
    if (!await widget.net.isReachable()) {
      _lift(1.0);
      _toOffline();
      return;
    }

    // One-shot push URL (cold-start tap) wins over everything.
    final flash = await widget.vault.takeFlashUrl();
    if (flash != null) {
      _lift(1.0);
      await _toPortal(flash);
      return;
    }

    final cached = await widget.gateway.cachedPortalUrl();

    await widget.attribution.start();
    await Future.wait([
      widget.attribution
          .awaitAttribution(RuntimeConfig.returningAttributionWait),
      widget.attribution.awaitDeepLink(),
    ]);
    _lift(0.75);

    final payload = await widget.attribution.buildPayload(
      locale: _locale(),
      pushToken: widget.push.token,
    );
    final verdict = await widget.gateway.resolve(payload);
    _lift(1.0);
    await Future.delayed(const Duration(milliseconds: 320));

    if (verdict.hasPortal) {
      await _toPortal(verdict.portalUrl!);
    } else if (cached != null && cached.isNotEmpty) {
      await _toPortal(cached);
    } else {
      _toOffline();
    }
  }

  Future<void> _runNative({bool quickBar = false}) async {
    _lift(0.4);
    await GameAssets().loadAll();
    _lift(1.0);
    await Future.delayed(
        Duration(milliseconds: quickBar ? 520 : 360));
    _toGame();
  }

  Future<void> _toPortal(String url) async {
    if (_handed) return;
    _handed = true;
    await portal.loadLibrary();
    await portal.warmupPortalEngine();
    if (!mounted) return;

    if (widget.vault.shouldOfferInvite) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PushInviteScreen(
            vault: widget.vault,
            push: widget.push,
            net: widget.net,
            portalUrl: url,
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => portal.PortalStage(
            url: url,
            vault: widget.vault,
            push: widget.push,
            net: widget.net,
          ),
        ),
      );
    }
  }

  void _toGame() {
    if (_handed) return;
    _handed = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen(storage: widget.gameStorage),
      ),
    );
  }

  void _toOffline() {
    if (_handed) return;
    _handed = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OfflineScreen(
          resumeBuilder: (_) => BootGate(
            vault: widget.vault,
            net: widget.net,
            attribution: widget.attribution,
            gateway: widget.gateway,
            push: widget.push,
            gameStorage: widget.gameStorage,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final art = landscape
        ? 'assets/Horizontal_Loading_Screen.jpg'
        : 'assets/Vertical_Loading_Screen.jpg';

    return Scaffold(
      backgroundColor: const Color(0xFF071A2B),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            art,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Color(0xFF071A2B)),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 42,
              ),
              child: SizedBox(
                width: MediaQuery.of(context).size.width *
                    (landscape ? 0.42 : 0.64),
                child: _ProgressRail(value: _progress),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRail extends StatefulWidget {
  final double value;
  const _ProgressRail({required this.value});

  @override
  State<_ProgressRail> createState() => _ProgressRailState();
}

class _ProgressRailState extends State<_ProgressRail> {
  int _dotCount = 0;
  Timer? _dotTimer;

  @override
  void initState() {
    super.initState();
    _dotTimer = Timer.periodic(const Duration(milliseconds: 430), (_) {
      if (mounted) setState(() => _dotCount = (_dotCount + 1) % 4);
    });
  }

  @override
  void dispose() {
    _dotTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 16,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.45),
              width: 1.6,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: widget.value),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOut,
                builder: (_, v, _) => FractionallySizedBox(
                  widthFactor: v <= 0 ? 0.001 : v,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF33D6FF), Color(0xFF6A3CFF)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // "LOADING" stays fixed width; only the dot suffix animates, in a
        // reserved-width box so the label never jitters side to side.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'LOADING',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
            SizedBox(
              width: 24,
              child: Text(
                '.' * _dotCount,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
