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

## Your work is kept

Pipelines live on disk and the app reopens whatever was last on screen. There is no save
button: edits write themselves, debounced so a drag costs one write. `Pipelines` in the
top bar lists what you have, and makes new ones, copies and deletions.

## Edges: who decides the flow

By default an edge **pulls**: the consumer takes what it needs and the producer is
sized to cover the total. Pin 20 duplicants and the Electrolyzers, the water and
the power all fall out. Switch an edge to **push** with an explicit `share` when
you want a deliberate split, or when auditing a base you have already built.

The one thing to know: a port drained only by pull edges must deliver *exactly*
what it makes — that equality is what sizes the producer. So a by-product you mean
to vent needs an output node to go to. Forget one and the solver says which port.

## Game data

`packages/oni_engine/lib/data/oni_data.json` is the source of truth; run
`fvm dart run tool/gen_data.dart` after editing it to refresh the embedded copy.

**Missing something?** Add it yourself: `+ Recipe` in the palette, or hover any entry and
hit `edit` to correct one. Hand-entered recipes are saved to disk, merged over the bundled
data, always tagged `unverified`, and can be reverted. New items can be invented on the
spot, so a DLC the app has never heard of is no longer a dead end.

Covers the base game, Spaced Out! and **The Aquatic Planet Pack**. Every process is
checked against [the wiki](https://oxygennotincluded.wiki.gg) and must carry either a
`verified` or an `unverified` tag — a test enforces it, an `unverified` process has to
explain what is doubtful, and the app warns you when you select one. Batch buildings
(Rock Crusher, Metal Refinery) are stated as continuous rates — 100 kg per 40 s
operation becomes 2500 g/s, with the duplicant's time booked as 600 s/cycle.
