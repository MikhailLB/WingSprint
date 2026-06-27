import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import 'game_assets.dart';
import 'game_engine.dart';
import 'game_painter.dart';
import 'models.dart';

const _logoAsset =
    'assets/PixVerse_Image_Effect_prompt_Game logo text _W-Photoroom.png';

class GameScreen extends StatefulWidget {
  final StorageService storage;
  const GameScreen({super.key, required this.storage});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  final GameEngine _engine = GameEngine();
  final GameAssets _assets = GameAssets();
  late final Ticker _ticker;
  final FocusNode _focusNode = FocusNode();
  Duration _lastTick = Duration.zero;

  bool _inGame = false;
  bool _showShop = false;
  bool _resultBanked = false;
  int _currentLevel = 1;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _currentLevel = widget.storage.level;
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 0.016
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (_inGame) {
      _engine.update(dt.clamp(0.0, 0.05));
      if ((_engine.state == GameState.gameOver ||
              _engine.state == GameState.levelComplete) &&
          !_resultBanked) {
        _bankResult();
      }
    } else {
      _engine.menuTime += dt;
    }
    if (mounted) setState(() {});
  }

  Future<void> _bankResult() async {
    _resultBanked = true;
    final s = widget.storage;
    await s.setCoins(s.coins + _engine.runCoins);
    await s.setBestEggs(_engine.delivered);
    if (_engine.state == GameState.levelComplete) {
      if (_currentLevel >= s.level) {
        await s.setLevel(_currentLevel + 1);
      }
    }
    if (mounted) setState(() {});
  }

  Loadout get _loadout => Loadout.fromTiers(widget.storage.allUpgradeTiers());

  void _startLevel(int level) {
    _currentLevel = level;
    _resultBanked = false;
    _engine.startLevel(LevelConfig.forLevel(level), _loadout);
    setState(() {
      _inGame = true;
      _showShop = false;
    });
  }

  void _returnToMenu() {
    setState(() {
      _inGame = false;
      _showShop = false;
    });
  }

  // ── input ──

  bool _swipeFired = false;
  void _onPanStart(DragStartDetails _) => _swipeFired = false;
  void _onPanUpdate(DragUpdateDetails d) {
    if (_swipeFired) return;
    final dx = d.delta.dx;
    final dy = d.delta.dy;
    const thr = 1.0;
    if (dx.abs() < thr && dy.abs() < thr) return;
    if (dx.abs() > dy.abs()) {
      _engine.setDirection(dx > 0 ? 1 : -1, 0);
    } else {
      _engine.setDirection(0, dy > 0 ? 1 : -1);
    }
    _swipeFired = true;
  }

  void _onPanEnd(DragEndDetails _) => _swipeFired = false;

  void _onKey(KeyEvent e) {
    if (e is! KeyDownEvent) return;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyA) {
      _engine.setDirection(-1, 0);
    } else if (k == LogicalKeyboardKey.arrowRight ||
        k == LogicalKeyboardKey.keyD) {
      _engine.setDirection(1, 0);
    } else if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.keyW) {
      _engine.setDirection(0, -1);
    } else if (k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.keyS) {
      _engine.setDirection(0, 1);
    } else if (k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.escape) {
      _engine.togglePause();
    }
  }

  // ── build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8ED14F),
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: _inGame ? _buildGame() : _buildMenu(),
      ),
    );
  }

  // ── MENU ──

  Widget _buildMenu() {
    final s = widget.storage;
    final pulse = (sin(_engine.menuTime * 3) + 1) / 2;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7EC6F4), Color(0xFFAEE06A), Color(0xFF7CB342)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _coinPill(s.coins),
                  const Spacer(),
                  _menuIconButton(
                      Icons.straighten, 'BEST ${s.bestEggs}', Colors.white),
                ],
              ),
            ),
            const Spacer(flex: 2),
            Image.asset(_logoAsset,
                width: MediaQuery.of(context).size.width * 0.8,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Text('WING SPRINT',
                    style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        color: Colors.white))),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('LEVEL $_currentLevel',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2)),
            ),
            const Spacer(flex: 2),
            Transform.scale(
              scale: 1 + pulse * 0.04,
              child: _bigButton('PLAY', Icons.play_arrow_rounded,
                  const [Color(0xFF66BB6A), Color(0xFF43A047)],
                  () => _startLevel(_currentLevel)),
            ),
            const SizedBox(height: 16),
            _bigButton('UPGRADES', Icons.storefront,
                const [Color(0xFFFFC107), Color(0xFFFF9800)],
                () => setState(() => _showShop = true)),
            const Spacer(flex: 3),
            _hintBar(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _hintBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'Swipe to run. Grab eggs at the basket, deliver them to the barn before the day ends. Dodge foxes & dogs!',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.3),
      ),
    );
  }

  // ── GAME ──

  Widget _buildGame() {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: CustomPaint(
              painter: GamePainter(engine: _engine, assets: _assets),
              size: Size.infinite,
            ),
          ),
        ),
        SafeArea(child: _buildHud()),
        if (_engine.state == GameState.paused) _buildPause(),
        if (_engine.state == GameState.levelComplete) _buildLevelComplete(),
        if (_engine.state == GameState.gameOver) _buildGameOver(),
        if (_showShop) _buildShop(),
      ],
    );
  }

  Widget _buildHud() {
    final e = _engine;
    final timeFrac = (e.timeLeft / e.config.dayTime).clamp(0.0, 1.0);
    final timeColor = timeFrac > 0.5
        ? Colors.greenAccent
        : (timeFrac > 0.25 ? Colors.amber : Colors.redAccent);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _hudPill(Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.local_shipping,
                        color: Color(0xFFFFD54F), size: 18),
                    const SizedBox(width: 5),
                    Text('${e.delivered}/${e.requiredEggs}',
                        style: _hudText),
                  ])),
                  const SizedBox(height: 5),
                  _hudPill(Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.egg, color: Colors.white, size: 16),
                    const SizedBox(width: 5),
                    Text('${e.carrying}/${e.capacity}', style: _hudText),
                  ])),
                ],
              ),
              const Spacer(),
              Column(children: [
                _hudPill(Text('LV $_currentLevel', style: _hudText)),
                const SizedBox(height: 5),
                Row(
                    children: List.generate(
                        e.loadout.startLives,
                        (i) => Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: Icon(Icons.favorite,
                                  size: 18,
                                  color: i < e.lives
                                      ? Colors.redAccent
                                      : Colors.white24),
                            ))),
              ]),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _coinPill(widget.storage.coins +
                      (_resultBanked ? 0 : e.runCoins)),
                  const SizedBox(height: 5),
                  GestureDetector(
                    onTap: () => e.togglePause(),
                    child: _hudPill(
                        const Icon(Icons.pause, color: Colors.white, size: 18)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          // day timer bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(children: [
              Container(height: 10, color: Colors.black.withValues(alpha: 0.3)),
              FractionallySizedBox(
                widthFactor: timeFrac,
                child: Container(height: 10, color: timeColor),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  static const _hudText = TextStyle(
      color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold);

  Widget _hudPill(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      );

  Widget _coinPill(int coins) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFFFC107), Color(0xFFFF9800)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.attach_money, color: Colors.white, size: 18),
          Text('$coins',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900)),
        ]),
      );

  Widget _menuIconButton(IconData icon, String label, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
      );

  // ── overlays ──

  Widget _buildPause() {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('PAUSED',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4)),
          const SizedBox(height: 24),
          _bigButton('RESUME', Icons.play_arrow_rounded,
              const [Color(0xFF66BB6A), Color(0xFF43A047)],
              () => _engine.togglePause()),
          const SizedBox(height: 14),
          _bigButton('MENU', Icons.home,
              const [Color(0xFF78909C), Color(0xFF546E7A)], _returnToMenu),
        ]),
      ),
    );
  }

  Widget _buildLevelComplete() {
    return Container(
      color: Colors.black.withValues(alpha: 0.78),
      child: Center(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('DAY COMPLETE!',
                style: TextStyle(
                    color: Color(0xFFFFD54F),
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    shadows: [Shadow(color: Colors.black, blurRadius: 8)])),
            const SizedBox(height: 8),
            Text('Level $_currentLevel cleared',
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 20),
            _resultRow(Icons.local_shipping, 'Delivered', '${_engine.delivered}'),
            _resultRow(Icons.attach_money, 'Coins earned', '+${_engine.runCoins}'),
            const SizedBox(height: 24),
            _bigButton('NEXT LEVEL', Icons.arrow_forward,
                const [Color(0xFF42A5F5), Color(0xFF1E88E5)],
                () => _startLevel(_currentLevel + 1)),
            const SizedBox(height: 14),
            _bigButton('MENU', Icons.home,
                const [Color(0xFF78909C), Color(0xFF546E7A)], _returnToMenu),
          ]),
        ),
      ),
    );
  }

  Widget _buildGameOver() {
    final ranOutOfTime = _engine.timeLeft <= 0;
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(ranOutOfTime ? "DAY'S OVER" : 'GAME OVER',
                style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    shadows: [Shadow(color: Colors.black, blurRadius: 8)])),
            const SizedBox(height: 8),
            Text(
                ranOutOfTime
                    ? 'You delivered ${_engine.delivered}/${_engine.requiredEggs}'
                    : 'The pack got you!',
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 20),
            _resultRow(
                Icons.local_shipping, 'Delivered', '${_engine.delivered}'),
            _resultRow(Icons.attach_money, 'Coins earned', '+${_engine.runCoins}'),
            const SizedBox(height: 24),
            _bigButton('RETRY', Icons.replay,
                const [Color(0xFF66BB6A), Color(0xFF43A047)],
                () => _startLevel(_currentLevel)),
            const SizedBox(height: 14),
            _bigButton('UPGRADES', Icons.storefront,
                const [Color(0xFFFFC107), Color(0xFFFF9800)], () {
              setState(() => _showShop = true);
            }),
            const SizedBox(height: 14),
            _bigButton('MENU', Icons.home,
                const [Color(0xFF78909C), Color(0xFF546E7A)], _returnToMenu),
          ]),
        ),
      ),
    );
  }

  Widget _resultRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 40),
        child: Row(children: [
          Icon(icon, color: Colors.amber, size: 20),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ]),
      );

  // ── SHOP ──

  Widget _buildShop() {
    final s = widget.storage;
    return Container(
      color: Colors.black.withValues(alpha: 0.92),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 14),
            const Text('UPGRADES',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3)),
            const SizedBox(height: 8),
            _coinPill(s.coins),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: kUpgrades.length,
                itemBuilder: (ctx, i) => _shopRow(kUpgrades[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _bigButton('CLOSE', Icons.close,
                  const [Color(0xFF78909C), Color(0xFF546E7A)],
                  () => setState(() => _showShop = false)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shopRow(UpgradeDef def) {
    final s = widget.storage;
    final tier = s.upgradeTier(def.type);
    final maxed = tier >= def.maxTier;
    final cost = maxed ? 0 : def.costs[tier];
    final canAfford = !maxed && s.coins >= cost;
    final nextLabel = def.tierLabels[(tier + (maxed ? 0 : 1))
        .clamp(0, def.tierLabels.length - 1)];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: def.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: def.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(def.icon, color: def.color, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(def.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Text(def.desc,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 11.5)),
                const SizedBox(height: 4),
                Row(children: [
                  ...List.generate(
                      def.maxTier,
                      (i) => Container(
                            width: 16,
                            height: 6,
                            margin: const EdgeInsets.only(right: 3),
                            decoration: BoxDecoration(
                              color: i < tier
                                  ? def.color
                                  : Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          )),
                  const SizedBox(width: 6),
                  Text(maxed ? 'MAX' : '→ $nextLabel',
                      style: TextStyle(
                          color: def.color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: maxed || !canAfford ? null : () => _buyUpgrade(def),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: maxed
                    ? null
                    : (canAfford
                        ? const LinearGradient(
                            colors: [Color(0xFFFFC107), Color(0xFFFF9800)])
                        : null),
                color: maxed
                    ? Colors.green.withValues(alpha: 0.2)
                    : (canAfford ? null : Colors.white.withValues(alpha: 0.08)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: maxed
                  ? const Icon(Icons.check, color: Colors.green, size: 20)
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.attach_money,
                          color: canAfford ? Colors.white : Colors.white38,
                          size: 16),
                      Text('$cost',
                          style: TextStyle(
                              color: canAfford ? Colors.white : Colors.white38,
                              fontSize: 14,
                              fontWeight: FontWeight.w900)),
                    ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _buyUpgrade(UpgradeDef def) async {
    final s = widget.storage;
    final tier = s.upgradeTier(def.type);
    if (tier >= def.maxTier) return;
    final cost = def.costs[tier];
    if (s.coins < cost) return;
    await s.setCoins(s.coins - cost);
    await s.setUpgradeTier(def.type, tier + 1);
    if (mounted) setState(() {});
  }

  // ── shared button ──

  Widget _bigButton(
      String label, IconData icon, List<Color> colors, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(34),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
          boxShadow: [
            BoxShadow(
                color: colors[0].withValues(alpha: 0.45),
                blurRadius: 14,
                offset: const Offset(0, 5)),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  shadows: [
                    Shadow(
                        color: Colors.black38,
                        blurRadius: 3,
                        offset: Offset(0, 2))
                  ])),
        ]),
      ),
    );
  }
}
