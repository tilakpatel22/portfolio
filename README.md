# Ship Traffic Control Sim

2.5D hyper-casual ship traffic control game for Android, made with **Godot 4.7.2** (GDScript, Compatibility renderer).
Draw routes from ships to matching ports, avoid collisions, and clear endless procedurally generated levels.

- Package: `io.github.tilakpatel22.shiptrafficcontrolsim`
- Game design and level algorithm: [DESIGN.md](DESIGN.md)
- Privacy policy: https://tdpzoide.blogspot.com/2026/10/ship-traffic-control-simulator-privacy.html
- Play Store listing text: [store/listing.md](store/listing.md)

## Open and run
1. Open `project.godot` in Godot 4.7.2.
2. Press Play (F5). AdMob shows mock ads in the editor.

## Build for Android
1. Editor Settings: set the Android SDK and Java (JDK 17+) paths.
2. Project → Install Android Build Template.
3. Project → Export → **Android AAB** (Play Store) or **Android APK** (testing).
   Debug builds always use Google test ads; release builds use the real AdMob IDs.
4. Sign release builds with your upload keystore (Export → Keystore → Release).

## Tests (headless)
```
godot --headless --path . -s tests/test_generator.gd     # level generator, 150 levels
godot --headless --path . -s tests/mechanics_test.gd     # mechanics stress test
godot --headless --path . -s tests/autoplay.gd -- 1 5    # autopilot plays levels via touch input
```

## Assets
- Music and sound effects are synthesized by `tools/gen_audio.py` (original, royalty-free).
- 3D models are procedural (`scripts/world/ship_models.gd`); fonts: Lilita One and Fredoka (SIL OFL).
- AdMob: [Poing Studios Godot AdMob plugin](https://github.com/poingstudios/godot-admob-plugin) v5.1.0 (MIT).
