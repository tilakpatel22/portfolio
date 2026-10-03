# Ship Traffic Control Sim — Optimized Prompt

> Build a **2.5D hyper-casual mobile game** in **Godot 4.7.2 (GDScript, Compatibility renderer, landscape)**,
> inspired by "Air Traffic Controller" games, but for **ships**.
> The player **drags a path** from each vessel to a **port of matching color/icon**. Two vessels touching = **crash = level failed**.
> Dock the target number of vessels to clear the level. **Unlimited procedurally generated levels**, each harder than the last.
> Stylized low-poly visuals: animated toon water with shore foam rings, sandy and grassy islands, trees, wakes and soft shadows.
> **10 vessel types** unlock over time. AdMob **interstitial after each cleared level** (natural break, 30 s cap).
> Screens: Splash/Menu, HUD, Pause, Level Complete, Game Over, Settings (music, sound, vibration, rate us, privacy).
> Original synthesized music and SFX. Saves progress locally. Android package `io.github.tilakpatel22.shiptrafficcontrolsim`.

## Core rules
| Rule | Detail |
|---|---|
| Control | Touch a vessel → drag → release. Path snaps to a matching dock. Segments over land are rejected. |
| Unguided vessels | Sail straight, steer away from land, bounce off screen edges. |
| Crash | Two vessels' hulls overlap. Near-misses show a red warning ring. |
| Win | `docked >= target`. Then interstitial → next level. |
| Fail | Crash → Retry (same seed = same level). |

## 10 vessels (unlock level → port)
| # | Vessel | Unlock | Port | Trait |
|---|---|---|---|---|
| 1 | Sailboat | 1 | Marina (yellow) | slow, small |
| 2 | Fishing Trawler | 1 | Fishing (green) | medium |
| 3 | Ferry | 3 | Passenger (blue) | medium |
| 4 | Speedboat | 5 | Marina (yellow) | very fast |
| 5 | Container Ship | 7 | Cargo (orange) | big, slow |
| 6 | Tugboat | 9 | **Any port** | wildcard |
| 7 | Cruise Liner | 12 | Passenger (blue) | huge |
| 8 | Oil Tanker | 15 | Fuel (red) | huge, slowest |
| 9 | Patrol Boat | 18 | Naval (purple) | fast |
| 10 | Submarine | 22 | Naval (purple) | dives: no collisions while submerged |

## Level generation algorithm (`scripts/core/level_generator.gd`)
All randomness comes from `seed = hash(level * 7919 + attempt)`, so a level is **identical on retry** and different from every other level.

**1. Difficulty curve.** A smooth ramp plus a 5-level tension wave (levels 5, 10, 15… are peak "Rush" levels, and the next level is a breather):
```
base = 1 - exp(-(L-1) / 22)          # 0 → ~1, saturates near L60
wave = [0, .04, .08, .12, .18][(L-1) % 5]
d    = clamp(base * 0.82 + wave, 0, 1)
endless = max(0, L - 50)             # keeps scaling forever after the curve saturates
```

**2. Parameters from `d`.**
```
target      = min(30, 5 + floor((L-1) * 0.6)) (+15% on peak levels)
max_active  = min(10, 2 + round(d * 6) + endless / 25)
spawn_every = lerp(6.5, 2.4, d) * rand(0.85, 1.15)   seconds
speed_mult  = min(1.6, lerp(0.9, 1.3, d) + endless * 0.003)
gates       = 2 + floor(d * 4)        # sea lanes where ships enter (2..6)
pool_size   = min(unlocked, 2 + floor(d * 4))
```

**3. Map archetype** (weighted by level, seeded). L1–2 are always one island.
- **Island**: one big central island.
- **Archipelago**: 2–4 noisy blob islands placed with Poisson spacing (channel ≥ 2.6 units).
- **Coast**: mainland along one edge plus 0–2 islands.
- **Strait**: mainland on two opposite edges, forming a channel.

Island shape: `r(θ) = R · (1 + Σ aₖ·sin(kθ + φₖ))` for k = 2, 3, 5, then elliptic stretch and rotation. Rocks (`min(6, (L-4)/4)` from L8) add obstacles.

**4. Ports.** One port per required class, plus extras up to `min(6, 2 + L/6)`. Ports sit on coastline vertices, facing open water, with a clear approach and spacing ≥ 4.

**5. Modifiers.**
- **RUSH**: peak levels from L5. Spawn ×0.75, pair spawns.
- **FOG**: from L12, 30% chance. Warning time cut from 2 s to 0.8 s.
- **CURRENT**: from L16, 30% chance. Drift on unguided ships.

**6. Fairness validation.**
- BFS on a 0.25-unit water grid (clearance ≥ 0.6) from every gate to every port.
- If anything is unreachable, regenerate with `attempt+1`. The fallback is the single-island map.

**7. Runtime director.**
- Never exceeds `max_active`.
- Picks the safest gate: unused recently, no vessel within 5 units, avoids repeats.
- Shows an edge warning arrow before entry.
- A newly unlocked vessel gets 2× spawn weight on its intro level and a "NEW VESSEL" card.

## Monetization and compliance
- AdMob App ID `ca-app-pub-1155049195805321~5850699185`.
- Interstitial `ca-app-pub-1155049195805321/9701390845`, shown when the player taps **Next**.
- Debug builds use Google test IDs automatically.
- UMP consent (GDPR) runs on launch; "Privacy options" appears in Settings when required.
- Privacy policy (Gamecept Studios): https://tdpzoide.blogspot.com/2026/10/ship-traffic-control-simulator-privacy.html
