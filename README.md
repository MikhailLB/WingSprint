# Wing Sprint 🐔

A cute cartoon **chicken‑courier** arcade game built with Flutter.

The hen runs around a cell field, grabs eggs at the basket (coop) and delivers
them to the barn **before the day runs out** — all while dodging wandering
foxes and chasing dogs. Hit an enemy and your carried eggs smash!

## Gameplay

- **Goal:** deliver the required number of eggs to the barn before the day timer
  ends.
- **Pick up** eggs by standing on the basket, **deliver** by reaching the barn.
- **Loose eggs** scattered on the field give bonus coins.
- **Enemies:** foxes wander, dogs hunt you. Touching one breaks your eggs and
  costs a life; short invincibility follows.
- **Lose** if the day ends before the quota or you run out of lives.

### Controls
- **Touch:** swipe up / down / left / right to set the running direction
  (Pac‑Man style — the hen keeps going and turns when it can).
- **Keyboard (desktop/web):** arrow keys or WASD to move, Space/Esc to pause.

## Progression

- **Levels** (`усложнение по уровням`): each level adds more foxes & dogs, faster
  enemies, a bigger field (more distance), a higher delivery quota, more
  obstacles and a shorter day. See `LevelConfig.forLevel` in
  `lib/game/models.dart`.
- **Upgrades shop** (`прокачка`): spend earned coins on permanent boosts —
  basket capacity, run speed, extra lives, slower enemies, a start shield and a
  coin multiplier.

## Orientation

- **Loading screen** supports **both** portrait and landscape (art swaps with
  device orientation), mirroring the AdventureRoad loader.
- **The game itself is portrait‑only** (locked on entering the game screen).

## Project structure

```
lib/
  main.dart                # bootstrap, orientation, storage init
  app.dart                 # MaterialApp + splash route
  screens/splash_screen.dart   # dual-orientation loading + asset preload
  services/storage_service.dart# coins, upgrades, level progress (SharedPreferences)
  game/
    models.dart            # upgrades, loadout, level difficulty scaling
    game_assets.dart       # image loading + chicken sprite-sheet slicing
    game_engine.dart       # grid, smooth movement, enemy AI, delivery, day timer
    game_painter.dart      # CustomPainter rendering of the whole scene
    game_screen.dart       # menu, HUD, shop, results, input
assets/                    # all art (chicken, fox, dog, eggs, tiles, UI, logo...)
```

## Run

```bash
flutter pub get
flutter run            # on a device/emulator
flutter run -d chrome  # quick test in the browser
```

## Tech

- Pure Flutter (`CustomPainter` + `Ticker` game loop), no game engine deps.
- Only runtime dependency: `shared_preferences` for saving progress.
