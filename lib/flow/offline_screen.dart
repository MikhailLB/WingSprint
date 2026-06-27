import 'package:flutter/material.dart';

// ============================================================
// OFFLINE SCREEN — full-bleed artwork + Retry
// ============================================================
// Uses the project's custom Nowifi artwork as a full-screen backdrop
// (orientation-aware) with a single glassy Retry pill anchored near
// the bottom. Retrying re-runs whatever screen produced this one via
// [resumeBuilder].
// ============================================================

class OfflineScreen extends StatefulWidget {
  final WidgetBuilder resumeBuilder;

  const OfflineScreen({super.key, required this.resumeBuilder});

  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_busy) return;
    setState(() => _busy = true);
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: widget.resumeBuilder));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final bg = landscape
        ? 'assets/Horizontal_Nowifi_Screen.webp'
        : 'assets/Vertical_Nowifi_Screen.webp';

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
              bottom: size.height * (landscape ? 0.08 : 0.10),
              child: Center(
                child: SizedBox(
                  width: landscape ? size.width * 0.32 : size.width * 0.56,
                  child: _SprintButton(
                    label: _busy ? 'Reconnecting' : 'Retry',
                    busy: _busy,
                    onTap: _retry,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SPRINT BUTTON — shared wing-themed action pill
// ============================================================
// A frosted, cyan→indigo gradient pill with a sliding sheen. Reused by
// the offline and push-invite screens so the gray flow has one
// consistent, project-specific button identity.
// ============================================================

class _SprintButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool busy;
  final bool slim;
  // compact = extra-small vertical padding (e.g. for Accept on push invite)
  final bool compact;

  const _SprintButton({
    required this.label,
    required this.onTap,
    this.busy = false,
    this.slim = false,
    this.compact = false,
  });

  @override
  State<_SprintButton> createState() => _SprintButtonState();
}

class _SprintButtonState extends State<_SprintButton>
    with SingleTickerProviderStateMixin {
  bool _down = false;
  late final AnimationController _sheen;

  @override
  void initState() {
    super.initState();
    _sheen = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double vPad;
    final double fontSize;
    if (widget.compact) {
      vPad = 10.0;
      fontSize = 15.0;
    } else if (widget.slim) {
      vPad = 12.0;
      fontSize = 16.0;
    } else {
      vPad = 17.0;
      fontSize = 19.0;
    }

    return GestureDetector(
      onTapDown: widget.busy ? null : (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: widget.busy
          ? null
          : (_) {
              setState(() => _down = false);
              widget.onTap();
            },
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          // No padding here — padding lives inside the Stack so the sheen
          // animation covers the entire button area (including top/bottom zones).
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF33D6FF), Color(0xFF3C6CFF), Color(0xFF6A3CFF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3C6CFF).withValues(alpha: 0.45),
                blurRadius: 22,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            // Slightly smaller radius avoids hairline artifact at border edge.
            borderRadius: BorderRadius.circular(21),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Sheen — Positioned.fill ensures it covers the FULL button
                // height including what used to be the top/bottom padding area.
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _sheen,
                    builder: (_, _) {
                      return Align(
                        alignment: Alignment(-1.4 + _sheen.value * 2.8, 0),
                        child: Container(
                          width: 60,
                          // double.infinity → Align passes max height from
                          // Positioned.fill, so sheen stretches edge-to-edge.
                          height: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.0),
                                Colors.white.withValues(alpha: 0.28),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Content — determines Stack height (= button height).
                Padding(
                  padding: EdgeInsets.symmetric(vertical: vPad),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.busy) ...[
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          shadows: const [
                            Shadow(
                              color: Colors.black38,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Public alias so sibling screens reuse the same button identity.
class SprintButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool busy;
  final bool slim;
  final bool compact;

  const SprintButton({
    super.key,
    required this.label,
    required this.onTap,
    this.busy = false,
    this.slim = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => _SprintButton(
    label: label,
    onTap: onTap,
    busy: busy,
    slim: slim,
    compact: compact,
  );
}
