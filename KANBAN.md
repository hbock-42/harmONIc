# ONI Pipeline Planner — Kanban

> **Goal**: a Flutter app where you sketch an *Oxygen Not Included* production pipeline as a graph
> (resources → buildings → resources), **pin one node** ("I have 3 Electrolyzers", "I have 10 kg/s of
> Water", "I want 1000 g/s of Oxygen"), and the whole graph re-solves itself: building counts, flow
> rates, power draw, heat output, dupe labour, leftovers and shortages.
>
> **Order of work**: engine first (pure Dart, testable, no Flutter), UI after.
> **Toolchain**: FVM-pinned Flutter, melos-free monorepo with a path-dependency pure-Dart package.

## Legend

| Tag | Meaning |
|---|---|
| `E#` | Epic |
| `P0` | Blocking / must exist for the engine to work at all |
| `P1` | Needed for a usable v1 |
| `P2` | Nice to have, post-v1 |
| `spike` | Research / decide, output is a written decision, not code |

---

## Board

### 🧊 Backlog

Everything not pulled into **Ready**. Grouped by epic below.

### 📋 Ready (next up)

- `E4-*` **Verify the game numbers** — every process tagged `unverified` in
  `oni_data.json` was typed from memory. Check each against the wiki, drop the tag.
- `E4-3..7` Widen the seed data (power, liquids, refining, food, critters)
- `E3-4` Whole-building rounding as a first-class solver mode (currently only a
  per-node `wholeCount` / `utilisation` getter)
- `E5-1..2` Save/load pipelines to disk
- `E6-2` `spike`: state management (recommendation: riverpod over the pure-Dart engine)
- `E7-1..4` The canvas: pan/zoom, node widgets, bezier edges, drag-to-connect

### 🚧 In Progress

_(empty)_

### ✅ Done

- `E0-1` FVM pinned to **3.47.1** (`.fvmrc`), `.fvm/` git-ignored
- `E0-2` Monorepo: `packages/oni_engine` (pure Dart) + `app/` (Flutter, path dep)
- `E0-3` Lints, `dart analyze` clean, `./tool/test_all.sh`
- `E1-1..4` `Unit`, `Item`, `Port`, `ProcessSpec`, `GameDatabase`
- `E1-6` `uptime` per node → `physicalCount` / `wholeCount` / `utilisation`
- `E2-1..6` `Pipeline`, `PipelineNode`, `PipelineEdge`, shares, `PipelineBuilder`, validation
- `E2-7` Cycles solve (power-loop SPOM regression test)
- `E3-0` `docs/SOLVER.md` written before the code
- `E3-1..3` Linear system + Gauss–Jordan + `PipelineSolution`
- `E3-5` Derived totals: power, heat, dupe labour, raw inputs, net outputs
- `E4-0..2` Data format, generator (`tool/gen_data.dart`), 39 items / 19 processes seeded,
  auto-generated `source:` / `sink:` processes per item
- `E5-1` `Pipeline` ⇄ JSON with a schema version
- `E8-1` 30 engine tests: DAG, cycle, splits, underdetermined, inconsistent, surplus, scaling

---

## E0 — Project scaffolding

| id | P | Task | Definition of done |
|---|---|---|---|
| E0-1 | P0 | FVM pin | `.fvmrc` pins an exact stable Flutter version; `fvm flutter --version` works; `.fvm/` git-ignored except config |
| E0-2 | P0 | Monorepo layout | `packages/oni_engine` (pure Dart, **no** flutter import), `app/` (Flutter), root `README.md` |
| E0-3 | P0 | Lints + CI-ready scripts | `very_good_analysis` or `flutter_lints`, `dart analyze` clean, `dart test` runs |
| E0-4 | P1 | GitHub Actions | analyze + test on push |
| E0-5 | P2 | `melos` or simple `tool/` shell scripts for multi-package commands | one command runs all tests |

## E1 — Domain model (the ONI vocabulary)

| id | P | Task | Notes |
|---|---|---|---|
| E1-1 | P0 | `Item` | id, display name, `ItemCategory` (solid / liquid / gas / power / heat / critter / plant / dupe-time / other), base unit |
| E1-2 | P0 | `Unit` + `Rate` | canonical internal units: **g/s** for mass, **W** for power, **kDTU/s** for heat, **count** for entities. Display conversion (g/s ↔ kg/s ↔ t/cycle) lives at the edge, never in the solver |
| E1-3 | P0 | `Port` | `(item, ratePerSecond, direction: input\|output, optional: temperature °C)` |
| E1-4 | P0 | `ProcessSpec` | id, name, kind (`building` \| `critter` \| `plant` \| `duplicant` \| `source` \| `sink`), ports, `powerDraw`, `heatOutput`, `dupeLabourPerCycle`, `footprint`, tags |
| E1-5 | P1 | Operating modes | one building = several specs (e.g. Oil Refinery is one, but Metal Refinery has one spec *per* metal; Generators have "on demand" vs "100% uptime") |
| E1-6 | P1 | `uptime` factor on a node | a building fed at 60 % runs at 60 %; solver works in "effective building-seconds", UI shows both `count` and `physicalCount = ceil(count/uptime)` |
| E1-7 | P1 | Temperature & phase | items carry a temperature; heat exchange is a *derived* report, not a solver constraint (v1) |
| E1-8 | P2 | Germs / disease | out of scope v1, keep a field so it can be added |

## E2 — Pipeline graph

| id | P | Task | Notes |
|---|---|---|---|
| E2-1 | P0 | `PipelineNode` | `id`, `specId`, `count` (the solved variable), `pin?` |
| E2-2 | P0 | `PipelineEdge` | `fromNode.outputPort → toNode.inputPort`, carries one item, has a `share` ∈ [0,1] of the source port's output |
| E2-3 | P0 | Auto-share | edges leaving the same output port default to an equal split; user can override. **This is what keeps the system square** — flows become a linear function of node counts only |
| E2-4 | P0 | `Pin` kinds | `buildingCount(n)`, `itemRate(item, g/s, at a port)`, `itemStock(item, mass, over duration)` → converted to a rate |
| E2-5 | P0 | Validation | edge item must match both ports; no duplicate edges; unknown spec ids; dangling pins |
| E2-6 | P1 | Free ports | an input port with no incoming edge = **external supply** (raw resource you must provide); an output port with no outgoing edge = **surplus/vent**. Both reported, never an error |
| E2-7 | P1 | Cycles | recycling loops (petroleum boiler, SPOM hydrogen return) must solve — the linear system handles them natively, add regression tests |
| E2-8 | P2 | Sub-pipelines | a saved pipeline usable as a single node in a bigger one |

## E3 — Solver (the heart)

| id | P | Task | Notes |
|---|---|---|---|
| E3-0 | P0 `spike` | Write `docs/SOLVER.md` | the maths, decided before code |
| E3-1 | P0 | Linear system build | Variables = node counts `x_n`. One equation per **fed** input port: `Σ_e share_e · x_src · outRate(src,item) = x_n · inRate(n,item)`. Plus one equation per pin |
| E3-2 | P0 | Gauss-Jordan w/ partial pivoting | dense is fine (graphs are ≤ a few hundred nodes); detect rank, report `underdetermined` (needs another pin) / `inconsistent` (contradictory pins) |
| E3-3 | P0 | Result object | per-node `count`, per-edge `flow` (g/s), per-item global balance, list of `Shortage` and `Surplus` |
| E3-4 | P1 | Rounding modes | `exact` (fractional buildings, the true ratio) vs `whole` (ceil to integers, then re-report the resulting surplus/idle %) — both shown |
| E3-5 | P1 | Derived totals | total power draw / generation, net power, total heat kDTU/s, dupe labour, footprint tiles, raw inputs list, net outputs list |
| E3-6 | P1 | Bottleneck detection | which node caps the pipeline when a raw input is capped |
| E3-7 | P2 | Simplex / LP upgrade | let the solver *choose* the shares to maximise a target output or minimise a raw input, instead of user-set shares |
| E3-8 | P2 | Sensitivity | "+1 Electrolyzer ⇒ +X g/s O₂, +Y W" |
| E3-9 | P1 | Solver perf test | 500-node graph solves < 50 ms |

## E4 — Game data

| id | P | Task | Notes |
|---|---|---|---|
| E4-0 | P0 `spike` | Decide data source | hand-curated JSON in `packages/oni_engine/data/` vs scraping the wiki. **Start hand-curated, seeded from the wiki, versioned per game update** |
| E4-1 | P0 | JSON schema + loader | `items.json`, `processes.json`, `buildings.json`; strict parsing with helpful errors; unit-tested against the shipped data |
| E4-2 | P0 | Seed set — oxygen | Electrolyzer, Algae Terrarium, Algae Distiller, Rust Deoxidizer, Oxylite Refinery, Deodorizer |
| E4-3 | P1 | Seed set — power | Coal / Wood / Natural Gas / Petroleum / Hydrogen / Steam / Solar generators, Transformers, Batteries (self-discharge) |
| E4-4 | P1 | Seed set — liquids | Water Sieve, Desalinator, Carbon Skimmer, Oil Well, Oil Refinery, Polymer Press, Ethanol Distiller |
| E4-5 | P1 | Seed set — refining | Metal Refinery (per ore), Rock Crusher, Kiln, Glass Forge, Molecular Forge |
| E4-6 | P1 | Seed set — food & farming | plants (per fertiliser/irrigation mode), Grill, Microbe Musher, Electric Grill, Gas Range |
| E4-7 | P1 | Seed set — duplicants | O₂ consumption, CO₂ / dirt / polluted-water output, calories, so "20 dupes" is a pinnable node |
| E4-8 | P2 | Ranching | critters: food in, meat/eggs/coal out, per-critter |
| E4-9 | P2 | DLC toggle | Spaced Out! variants (rockets, radiation), base-game filter |
| E4-10 | P1 | Data version stamp | `dataVersion` + game build in the JSON so saved pipelines can warn on mismatch |

## E5 — Persistence & interop

| id | P | Task |
|---|---|---|
| E5-1 | P1 | `Pipeline` ⇄ JSON (`toJson`/`fromJson`) with a schema version + migrations hook |
| E5-2 | P1 | Local save/load of user pipelines (`path_provider` + file, or `hive`/`isar` — decide in a spike) |
| E5-3 | P2 | Share a pipeline as a link / base64 blob |
| E5-4 | P2 | Import/export to clipboard |

## E6 — App shell (Flutter)

| id | P | Task |
|---|---|---|
| E6-1 | P1 | App scaffold, theming (dark, ONI-ish palette), routing (`go_router`) |
| E6-2 | P1 | State management decision `spike` → `riverpod` (recommended: pure-Dart engine + riverpod providers) |
| E6-3 | P1 | Pipeline list / new / open / delete |
| E6-4 | P1 | Desktop + web targets first (canvas work is mouse-first), mobile later |

## E7 — Graph canvas UI

| id | P | Task |
|---|---|---|
| E7-1 | P1 | Pan/zoom canvas (`InteractiveViewer` or custom `Transform` + gesture layer) |
| E7-2 | P1 | Node widget: icon, name, solved count, ports as dots |
| E7-3 | P1 | Edge rendering: bezier `CustomPainter`, thickness ∝ flow, colour by item category |
| E7-4 | P1 | Drag-from-port to create an edge, with type-compat highlighting |
| E7-5 | P1 | Node palette / search to add a process |
| E7-6 | P1 | **Pin UI** — the headline feature: click a node → "I have ▢ of these" / "I want ▢ g/s out"; pinned node gets a lock badge; everything else recomputes live |
| E7-7 | P1 | Inspector panel: per-node inputs/outputs, power, heat, uptime |
| E7-8 | P1 | Summary bar: net power, net heat, raw inputs, net outputs, shortages |
| E7-9 | P2 | Auto-layout (layered / Sugiyama) for imported or generated graphs |
| E7-10 | P2 | Undo/redo |
| E7-11 | P2 | Multi-select, group, collapse into sub-pipeline |

## E8 — Quality

| id | P | Task |
|---|---|---|
| E8-1 | P0 | Unit tests for every solver path (DAG, cycle, underdetermined, inconsistent, shortage, surplus) |
| E8-2 | P1 | Golden real-world scenarios: SPOM, petroleum boiler, oxylite chain, coal farm — with hand-checked expected numbers |
| E8-3 | P1 | Property test: any solved graph satisfies mass balance within ε |
| E8-4 | P2 | Widget/golden tests for the canvas |
| E8-5 | P2 | Benchmarks in CI |

---

## Milestones

- **M1 — Engine walking skeleton**: E0 + E1-1..4 + E2-1..5 + E3-1..3 + E4-1..2 + E8-1.
  *Proof*: a Dart test builds "Water → Electrolyzer → O₂/H₂ → Hydrogen Generator", pins `3 Electrolyzers`,
  and asserts water in, O₂ out, H₂ out, net power.
- **M2 — Engine v1**: cycles, pins of every kind, whole-building rounding, derived totals, real data seed, golden scenarios.
- **M3 — App v1**: canvas, node palette, pin UI, summary bar, save/load.
- **M4 — Polish**: auto-layout, undo/redo, LP optimiser, sharing.
