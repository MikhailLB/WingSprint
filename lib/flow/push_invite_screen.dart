import 'package:flutter/material.dart';
import '../core/net_sensor.dart';
import '../core/push_center.dart';
import '../core/vault.dart';
import 'offline_screen.dart' show SprintButton;
import 'portal_stage.dart' deferred as portal;

// ============================================================
// PUSH INVITE SCREEN — opt-in promo shown once before the portal
// ============================================================
// Custom Notifications artwork as the backdrop with an Accept pill and
// a quieter Skip link. Either choice routes onward to the portal; the
// gating (cooldown / grant / hard-deny) lives in Vault + PushCenter.
// ============================================================

class PushInviteScreen extends StatefulWidget {
  final Vault vault;
  final PushCenter push;
  final NetSensor net;
  final String portalUrl;

  const PushInviteScreen({
    super.key,
    required this.vault,
    required this.push,
    required this.net,
    required this.portalUrl,
  });

  @override
  State<PushInviteScreen> createState() => _PushInviteScreenState();
}

class _PushInviteScreenState extends State<PushInviteScreen> {
  bool _leaving = false;

  Future<void> _accept() async {
    final granted = await widget.push.askPermission();
    if (!granted) {
      await widget.vault.snoozeInvite();
    }
    await _enterPortal();
  }

  Future<void> _skip() async {
    await widget.vault.snoozeInvite();
    await _enterPortal();
  }

  Future<void> _enterPortal() async {
    if (_leaving) return;
    _leaving = true;
    await portal.loadLibrary();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => portal.PortalStage(
          url: widget.portalUrl,
          vault: widget.vault,
          push: widget.push,
          net: widget.net,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final bg = landscape
        ? 'assets/Horizontal_Notifications_Screen.webp'
        : 'assets/Vertical_Notifications_Screen.webp';

    return Scaffold(
      backgroundColor: const Color(0xFF071A2B),
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              bg,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: Color(0xFF071A2B)),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: size.height * (landscape ? 0.07 : 0.085),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Accept — smaller pill (52 % width in portrait, 28 % in landscape)
                  Center(
                    child: SizedBox(
                      width: landscape
                          ? size.width * 0.28
                          : size.width * 0.52,
                      child: SprintButton(
                        label: 'Accept',
                        compact: true,
                        onTap: _accept,
                      ),
                    ),
                  ),
                  SizedBox(height: landscape ? 10 : 16),
                  _SkipButton(onTap: _skip),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Visible outlined Skip button — clearly tappable but secondary to Accept.
class _SkipButton extends StatefulWidget {
  final VoidCallback onTap;
  const _SkipButton({required this.onTap});

  @override
  State<_SkipButton> createState() => _SkipButtonState();
}

class _SkipButtonState extends State<_SkipButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 44),
        decoration: BoxDecoration(
          // Solid dark fill so the label reads clearly over the busy art.
          color: _down
              ? Colors.black.withValues(alpha: 0.72)
              : Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withValues(alpha: _down ? 1.0 : 0.90),
            width: 2.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Text(
          'Skip',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            shadows: [
              Shadow(
                  color: Colors.black87, blurRadius: 6, offset: Offset(0, 1)),
            ],
          ),
        ),
      ),
    );
  }
}
