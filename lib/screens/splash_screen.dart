import 'package:flutter/material.dart';
import '../game/game_assets.dart';
import '../game/game_screen.dart';
import '../services/storage_service.dart';

/// Loading screen. Shows the branded artwork in BOTH orientations
/// (portrait & landscape), preloads game images, then routes into the
/// portrait-locked game. Mirrors AdventureRoad's dual-orientation loader.
class SplashScreen extends StatefulWidget {
  final StorageService storage;
  const SplashScreen({super.key, required this.storage});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _barController;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _barController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
    _boot();
  }

  Future<void> _boot() async {
    final results = await Future.wait([
      GameAssets().loadAll(),
      Future.delayed(const Duration(milliseconds: 1500)),
    ]);
    results.length; // ensure both complete
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GameScreen(storage: widget.storage)),
    );
  }

  @override
  void dispose() {
    _barController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final art = isLandscape
        ? 'assets/Horizontal_Loading_Screen.png'
        : 'assets/Vertical_Loading_Screen.png';

    return Scaffold(
      backgroundColor: const Color(0xFF8ED14F),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            art,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Color(0xFF8ED14F)),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 40),
              child: SizedBox(
                width: MediaQuery.of(context).size.width *
                    (isLandscape ? 0.4 : 0.62),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _loadingBar(),
                    const SizedBox(height: 10),
                    const Text(
                      'LOADING...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 4)
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingBar() {
    return Container(
      height: 18,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AnimatedBuilder(
          animation: _barController,
          builder: (_, _) => Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: _barController.value,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFFFFE082), Color(0xFFFFB300)]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
