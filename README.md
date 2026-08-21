# ONI Pipeline Planner

Plan *Oxygen Not Included* production chains: draw the pipeline, **pin one node**
("I have 3 Electrolyzers", "my geyser gives 2 kg/s of water", "I want 1 kg/s of
oxygen"), and every other building, flow, watt and kDTU scales to match.

## Layout

```
packages/oni_engine/   pure Dart — model, solver, game data. No Flutter.
app/                   Flutter app (macOS, web, iOS, Android).
docs/SOLVER.md         how the solver works, decided before it was written.
KANBAN.md              the plan, epic by epic.
```

## Toolchain

Flutter is pinned with [FVM](https://fvm.app) — see `.fvmrc`. Always prefix commands:

```bash
fvm flutter run -d macos       # the app
fvm dart test                  # from packages/oni_engine
./tool/test_all.sh             # everything
```

## Try the engine without the UI

```bash
cd packages/oni_engine
fvm dart run example/spom.dart
```

```
=== "I have 4 Electrolyzers" ===
Buildings
      4.00 × Electrolyzer          → build 4 (100 % busy)
      4.48 × Hydrogen Generator    → build 5 (90 % busy)
Inputs needed
  Water: 4.00 kg/s
Outputs
  Oxygen: 3.55 kg/s
Power
  net:       3.10 kW
Heat: 22.92 kDTU/s
```

## How the engine thinks

One variable per node (how many of it are running), one linear equation per fed
input port, one per pin — solved as a single system. Recycling loops (SPOM
hydrogen return, petroleum boilers) need no special case: they are just entries
on the other side of the diagonal. Power (W) and heat (kDTU/s) are ordinary
items, so the power budget falls out of the same balance sheet as the mass.

Full write-up: [`docs/SOLVER.md`](docs/SOLVER.md).

## Game data

`packages/oni_engine/lib/data/oni_data.json` is the source of truth; run
`fvm dart run tool/gen_data.dart` after editing it to refresh the embedded copy.

⚠️ Processes tagged **`unverified`** were entered from memory and still need
checking against the wiki — see `KANBAN.md` epic **E4**.
