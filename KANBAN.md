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

- `E7-9` auto-layout, `E7-10` marquee select, `E7-11` minimap
- `E5-1..2` Save/load pipelines to disk — the app has no persistence yet, so a
  reload loses your build. Next most valuable thing after the canvas
- `E10-5` a real problems *panel* (the banner shows the first three)
- `E5-3` Export/import a pipeline as a file or a link, to share a build
- `E6-6` Tabs, so two pipelines can be compared side by side
- `E4-3..7` Widen the seed data (food and cooking, ranching, the remaining generators)
- `E4-9` **Still blocked on wiki stubs, not on us.** Plants: 5 of 12 seeded; Sodicane
  (no quantified yield), Bulbloom (decor only), Mussel Sprout (non-renewable), Clampum,
  Pinpoket, Petta Pouf and Husha Cups have no usable numbers. Aquatic critters: only
  Blowter is seeded — Beakon, Slogo, Gildgo, Seaquine, Orehull, Kelpole and Glo Squid
  list *what* they eat and make but not *how much*. Ranching/food buildings likewise
- `E4-15` More base-game critters: Pip, Shine Bug, Pokeshell, Gassy Moo, Shove Vole,
  Plug Slug, and the Frosty/Prehistoric pack critters
- `E4-22` The Grooming Station's power draw, if it is ever published — modelled as zero
  today, which under-reports the grid
- `E4-20` Egg mass and shells: eggs are counted, not weighed, so shell-to-lime and
  omelette chains cannot be modelled yet
- `E4-21` Wild versus groomed as separate specs — the seeded figures assume groomed
- `E4-15` More base-game critters: Pip, Shine Bug, Pokeshell, Gassy Moo, Shove Vole
- `E4-11` Nail down the `unverified` DLC rates: the Vulcanizer's full recipe, the Plant
  Pulverizer's cycle time, the Marine Drill's natural gas output, Gum Palm's CO2
- `E4-12` DLC filter in the palette, so a base-game player is not offered Aquatic content
- `E3-7b` `allowSurplus` per output port, so a vented by-product does not need a
  sink node just to keep the system consistent
- `E3-4` Whole-building rounding as a first-class solver mode (currently only a
  per-node `wholeCount` / `utilisation` getter)
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
- `E8-1` 41 engine tests: DAG, cycle, splits, pull/push, underdetermined, inconsistent,
  surplus, scaling, wiki-regression numbers
- `E2-2` **Demand-driven edges** — `EdgeMode.pull` (default) sizes a producer from what
  its consumers take; `EdgeMode.push` keeps fixed-fraction splits for audits. Two
  consumers on one output now add up instead of being carved 50/50
- `E3-6` Inconsistent systems name the output ports with nowhere to vent, instead of
  just reporting a contradiction
- `E6-1..4` forui wired up, **no Material anywhere in `app/lib`** (bare `WidgetsApp`),
  `PipelineController` with re-solve-on-edit and undo/redo
- `E9-1..3` Design tokens, the item-category palette, and the `lib/design/` wrappers
- `E7-1..8` **The canvas**: pan/zoom, node widgets, bezier wires with thickness ∝ flow,
  selection, node dragging with grid snap, drag-from-port to connect, delete, empty state
- `E10-1..4` Palette with search, the **pin control**, node/edge inspectors, summary bar,
  problems banner
- `E7-6`+ **Click a port to fill it** — clicking any port asks what belongs on the other
  end, filtered to processes with a matching port, and places *and* wires the choice in
  one undo step, lined up so the wire runs flat. Dropping a wire on empty canvas opens
  the same menu instead of discarding the gesture. Following the hollow dots outwards
  is now the fastest way to build a chain
- `E8-4` 42 app tests: controller, node widget geometry, canvas coordinates and gestures,
  editor flows
- `E4-19` **Ranching buildings** — Grooming, Aquatic Grooming and Shearing Stations, sized
  by the critters that need them through a `grooming` / `shearing` capacity link rather
  than a pin, so twenty Hatches asks for three stables on its own. The stations carry no
  labour: the Duplicant time is booked on the critters, and charging it twice would be
  worse than not charging it at all. Shearing adds its own time on top — 12 s every
  8 cycles for a Drecko, every 3 for a Glossy
- `E4-16` **Ranching costs and yields** — critters lay eggs (one per groomed interval),
  drop meat spread over their lifespan, and cost 12 s of Duplicant time a cycle each to
  keep groomed. The summary bar shows total labour in seconds *and* in Duplicants, and
  turns amber past a whole one, so a ranch stops reading as free
- `E4-18` **Measured geyser figures** — type the exact active percentage Field Research
  reports, not just a preset band. The field shows the resulting output rate beside it,
  refuses anything outside 1–100 rather than clamping silently, and stays in step when the
  presets or the all-geysers control change the value from elsewhere
- `E4-14` **Geyser activity** — `PipelineNode.outputScale` scales what a node produces
  without touching what it consumes, and the inspector offers worst/typical/best (40/60/80 %)
  per geyser, with a top-bar control to swing them all at once in a single undo step.
  Chasing this down found that the wiki's two figures differ by exactly the typical active
  share: the per-geyser pages quote the *while-active* average, the summary table the
  *lifetime* one. The shipped rates are lifetime averages, and now say so
- `E5-1..2` **Save and load** — every pipeline is kept on disk and the app reopens the
  one you had on screen. Editing saves itself, debounced so a drag is one write rather
  than sixty, and selecting a node is not treated as an edit. New, duplicate, delete and
  rename live in the Pipelines menu; a first run adopts the starter build as a real saved
  pipeline instead of something that evaporates when the window closes
- `E4-13` **User-defined recipes** — add or correct a process from inside the app, saved
  to disk and merged over the bundled data by id. A hand-entered recipe is always tagged
  `unverified`, new items can be invented on the spot for content the app has never heard
  of, and an override can be reverted to restore the shipped numbers. The canvas re-solves
  the moment you save
- `E5-2a` Persistence groundwork: `UserDataStore` behind an interface, so the pipeline
  save/load in `E5` reuses it and tests never touch the disk
- `E4-8` **Critters**: 14 ranching staples with wiki rates — Hatch/Sage/Smooth, Slickster
  and Molten Slickster, the four Pufts, Drecko and Glossy Drecko, Pacu, Gulp Fish and
  Blowter. Feed in, product out, so a ranch sizes itself from your CO2 or your algae
- `E4-14a` **Geysers, vents and volcanoes** — 19 natural sources with their wiki average
  rates and output temperatures, modelled as discrete features so pinning one means
  "I have one geyser". The Tidal Spring is modelled as the recirculator it is
- `E6-5` **Keyboard**: ⌫/⌦ delete, ⌘Z/⇧⌘Z undo, Esc deselect — and clicking the canvas
  now takes focus off any text field, without which the typing guard permanently
  disabled the delete shortcut
- `E4-8/10` **The Aquatic Planet Pack** (June 2026): 28 new elements, the rubber chain
  (Gum Palm → Plant Pulverizer → Vulcanizer), Tidal Turbine, Marine Drill, and the
  Desalinator's polluted-brine recipe. Numbers that the wiki does not publish are tagged
  `unverified`, must say why in their description (enforced by a test), and the inspector
  warns on them
- `E4-*` **Every process checked against the wiki** (oxygennotincluded.wiki.gg, 2026-08-21).
  12 of 19 were wrong; the Desalinator split into one spec per recipe; batch buildings
  restated as continuous rates. A test now fails if any process loses its `verified` tag

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
| E3-7b | P1 | `allowSurplus` per output port | today a vented by-product needs a sink node, because a pulled output port must balance exactly |
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
| E4-11 | P1 | Confirm the unverified DLC rates once the wiki fills them in |
| E4-12 | P2 | Palette filter by DLC |
| E4-13 | ✅ | User-defined / overridable processes, edited in the app |
| E4-17 | P2 | Share a custom recipe pack, so a wiki gap gets filled once for everyone |
| E4-10 | P1 | Data version stamp | `dataVersion` + game build in the JSON so saved pipelines can warn on mismatch |

## E5 — Persistence & interop

| id | P | Task |
|---|---|---|
| E5-1 | P1 | `Pipeline` ⇄ JSON (`toJson`/`fromJson`) with a schema version + migrations hook |
| E5-2 | P1 | Local save/load of user pipelines (`path_provider` + file, or `hive`/`isar` — decide in a spike) |
| E5-3 | P2 | Share a pipeline as a link / base64 blob |
| E5-4 | P2 | Import/export to clipboard |

## E6 — App shell & foundations

**Decided (2026-08-21):** [`forui`](https://pub.dev/packages/forui) `^0.25` for the chrome,
hand-written canvas on `package:flutter/widgets.dart`. Every forui call sits behind an
app-local wrapper in `lib/design/`, so a `0.x` breaking change lands in one folder.
Visual direction: **technical planner** — dark, dense, colour used as data.

> Flutter 3.47 decoupled Material/Cupertino into standalone `material_ui` / `cupertino_ui`
> packages (opt-in; bundled imports deprecate in the Fall 2026 stable). We depend on
> neither — forui has no Material dependency — so there is nothing to migrate in November.

| id | P | Task | Definition of done |
|---|---|---|---|
| E6-1 | P0 | forui wired up, Material dropped | no `package:flutter/material.dart` anywhere in `app/lib` |
| E6-2 | P0 | State management | `PipelineController extends ChangeNotifier`: holds the `Pipeline`, the current `PipelineSolution`, selection, and an undo stack. No riverpod — the engine is pure and the app has one document |
| E6-3 | P0 | Re-solve on every edit | any mutation re-runs the solver and repaints; target < 16 ms for a 100-node graph |
| E6-4 | P1 | Undo/redo | trivial: `Pipeline` is immutable, so the stack is a `List<Pipeline>` |
| E6-5 | P1 | Desktop-first window chrome, keyboard shortcuts (⌘Z, ⌫, ⌘F) |
| E6-6 | P2 | Multi-document: open several pipelines in tabs |

## E9 — Design system (`lib/design/`)

| id | P | Task | Notes |
|---|---|---|---|
| E9-1 | P0 | Tokens | `OniColors`, `OniSpacing`, `OniTypography`. One dark palette; colour is *data*, not decoration |
| E9-2 | P0 | Item-category palette | solid / liquid / gas / power / heat each get a hue, used identically on ports, edges and legends — the single most important visual rule in the app |
| E9-3 | P0 | Wrappers | `OniPanel`, `OniButton`, `OniField`, `OniSelect`, `OniTooltip` over forui equivalents |
| E9-4 | P1 | Numeric formatting widget | reuses the engine's `Unit.format`; per-second ⇄ per-cycle toggle in one place |
| E9-5 | P1 | Icon set | no game sprites (copyright) — generated glyphs per item category |
| E9-6 | P2 | Light theme |

## E7 — The canvas

The part no library gives us: `widgets.dart` + `CustomPainter` + raw gestures.

| id | P | Task | Notes |
|---|---|---|---|
| E7-1 | P0 | Viewport | `Matrix4` pan/zoom driven by `Listener` + `GestureDetector`; explicit screen ⇄ world coordinate conversion, because every hit test needs it. Trackpad pinch and scroll-to-pan |
| E7-2 | P0 | Node widget | real widgets inside a `Stack` (not painted), so text, focus and hit-testing come free. Shows name, solved count, `build N`, a utilisation bar, and its ports as dots |
| E7-3 | P0 | Edge painter | one `CustomPaint` *under* the nodes: bezier per edge, colour by item category, **thickness ∝ flow**, flow label at the midpoint |
| E7-4 | P0 | Selection | click a node or an edge; selection drives the inspector |
| E7-5 | P0 | Drag a node | updates `PipelineNode.x/y`, snaps to a grid |
| E7-6 | P1 | Drag-from-port to connect | live bezier following the cursor; compatible target ports light up, incompatible ones dim; drop on empty space opens the palette filtered to processes that accept that item |
| E7-7 | P1 | Delete | node or edge, with the edges of a deleted node going too |
| E7-8 | P1 | Empty state | a real "add your first node" affordance, not a blank void |
| E7-9 | P2 | Auto-layout (layered / Sugiyama) |
| E7-10 | P2 | Marquee select, group move |
| E7-11 | P2 | Minimap |

## E10 — Panels & the pin interaction

| id | P | Task | Notes |
|---|---|---|---|
| E10-1 | P0 | Process palette | searchable, grouped by tag (oxygen / power / liquid / refining), click or drag to place. Sources and sinks listed per item |
| E10-2 | P0 | **Pin control** — the headline | select a node → "I have ▢ of these" (buildings) or "▢ g/s" (source/sink). Pinned node wears a lock badge; clearing it is one click |
| E10-3 | P0 | Inspector | selected node: every port with its solved rate, what is connected, power, heat, uptime, and the `unverified` warning if the data ever carries one |
| E10-4 | P1 | Summary bar | net power, total heat, raw inputs, net outputs, dupe labour — always visible |
| E10-5 | P1 | Problems panel | solver issues as a real list: underdetermined (with the "pin one of these" nodes as buttons), inconsistent, shortages |
| E10-6 | P1 | Edge inspector | pull ⇄ push toggle and the share slider, explained in words rather than jargon |
| E10-7 | P2 | Per-cycle ⇄ per-second toggle |
| E10-8 | P2 | Templates: start from SPOM, petroleum boiler, coal farm |

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
  *Proof*: build the SPOM from an empty canvas by hand — place nodes, drag the connections,
  pin the crew — without touching a line of Dart.
- **M4 — Polish**: auto-layout, undo/redo, LP optimiser, sharing.
