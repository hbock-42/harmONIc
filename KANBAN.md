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

**Canvas and interaction**

- `E7-13` Marquee needs ⇧ because a plain drag pans. Space-drag-to-pan would free the
  plain drag for selection, which is what most editors do
- `E6-6` Tabs, so two pipelines can be compared side by side

**Things the model cannot yet say**

- `E11-2` Pipe materials: 500 °C steam needs a pipe built of something that survives it,
  which depends on the material's limits rather than the flow's temperature alone
- `E11-6` Temperature mixing: two flows meeting average out by mass and specific heat; the
  app reports the temperature a port declares, no more
- `E11-5` Conduit heat: a pipe full of 95 °C water heats whatever it runs past
- `E11-4` Filters and valves: a Gas Filter separates one gas from a mixed stream, and this
  model has no notion of a mixture
- `E4-20` Egg mass and shells, so shell-to-lime and omelette chains can be modelled
- `E4-21b` Glo Squid and Seaquine wild twins, once somebody checks in game which of
  their outputs the milking station takes and which they give off anyway

**Data still to gather**

- `E12-5` Sage Hatch eats organics broadly — polluted dirt, slime, algae, dirt, fertiliser
  and most Duplicant food. That is a class this app does not have, and inventing one
  called "organic" without checking what the game really groups would be a guess
- `E12-6` Alternative diets: a Plug Slug eats metal ore *or* refined metal, and the model
  has no "either" — the Beakon pattern (one spec per diet) is the answer, and nobody has
  written the second spec yet
- `E12-7` Rot Pile, so a Pokeshell's second food and the Compost's second input exist
- `E12-4` Lead, and the metals behind galena: the ore is in the class but has nothing to
  refine into, so a refinery set to galena cannot say what it made
- `E12-2` The rest of the roster now that classes make it cheap: Aquatuner and Thermo
  Regulator (they move heat rather than make it, so the heat item needs a sign convention
  first), Supermaterial Refinery, Molecular Forge, Spice Grinder, Dehydrator, Smoker
- `E12-3` The Crafting Station: every recipe is known except how many gaskets 50 kg of
  plastic makes, which is the one figure a build actually needs

- `E11-7b` What a Gasket costs: 50 kg of plastic or rubber makes some number of them, and
  the wiki does not say how many, so a build wanting four is priced in gaskets rather than
  in the plastic behind them

- `E4-34b` The Microbe Musher and Smoker: their pages list what each recipe yields but not
  what goes into it, so there is nothing to model yet. Food *quality* likewise — the model
  has no notion of it, and morale is half the reason anyone cooks
- `E4-35b` Sporechid, and the Prehistoric and Aquatic food plants
- `E4-27` Mercury and cinnabar processing
- `E4-26` The rest of both packs: Bammoth and Jawbo (yields unpublished), Rhex (eats other
  critters, which a flow model cannot express), Gnit and Mimika (produce nothing), and the
  regular Lumb (its peat rate is stated nowhere)
- `E4-9` Aquatic plants: 5 of 12 seeded. Sodicane, Bulbloom, Mussel Sprout, Clampum,
  Pinpoket, Petta Pouf and Husha Cups have no usable numbers. Check each page individually
  rather than the summary table — that mistake cost us the whole critter roster once
- `E4-23` Beeta, Sweetle and Grubgrub: rates unpublished, and a Beeta's 5-cycle life would
  be misrepresented by a per-cycle average
- `E4-32` Bammoth on Plume Squash, and Thimble Reed as the Pip's other crop
- `E4-28` Seaquine's ovolene rate
- `E4-25` Firm up the inferred 50 % conversions on Pip and Pokeshell, and the Shine Bug's
  feed in kilograms
- `E4-11` Nail down the unverified DLC rates: the Vulcanizer's recipe, the Plant
  Pulverizer's cycle time, the Marine Drill's natural gas, Gum Palm's CO2
- `E4-22` The Grooming Station's power draw, if it is ever published

**Saving and sharing**

- `E5-4` Export to a file, for archiving rather than pasting — wants a file-picker
  dependency nothing else has needed

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
- `E4-12` **Palette filters** — packs and wild variants can be switched off, remembered
  between runs. Two thirds of the catalogue was content a base-game player cannot build.
  The header says how much is being kept back, so a filter set last week is not mistaken
  for an empty database
- `E7-14` **The view follows a drag off the edge** — hold a node, a selection, a rubber band
  or a half-drawn wire against the window edge and the canvas pans, faster the harder you
  press. The dragged thing keeps moving even while the pointer sits still, which is the
  half that makes it useful
- `E12-1c` **Classes applied where they were verified** — Filtration Medium (Deodorizer and
  Water Sieve take sand *or* regolith), a Hatch eats rock rather than one rock, a Smooth
  Hatch eats any ore and gives back the matching metal at 75 %, and the Ethanol Distiller
  burns wood whichever tree it came off. Plus a Rock Crusher metal recipe, and a
  duplicate-id guard after two shipped specs turned out to be invisible copies
- `E12-1b` **Naming the metal** — a node can say which member of a class it is using, and
  an output that follows an input takes it: copper ore in, copper out. Unset stays generic
  and feeds anything; chosen feeds only what it really is, and the wiring is checked
  against the choice rather than the recipe
- `E12-1` **Material classes** — a port can ask for "Metal Ore" and take any of them. It is
  a compatibility rule rather than a new kind of flow, so the solver never learned about
  it: everything was already grams. One Metal Refinery in the palette instead of one per
  ore, and 12 more converters seeded — Oxygen Diffuser, Steam Turbine, Oil Well, Glass
  Forge, Kiln, Compost, Fertilizer Synthesizer, Sublimation Station and the rest
- `E11-7` **Construction materials** — all 36 buildings priced from the wiki, including the
  pumps the engine synthesises. Counted per building placed rather than per fractional one,
  and in the class the game asks for: any metal ore will do
- `E5-6` **Corrected recipes are named** — a saved build now carries the rates its recipes
  had when it was written, so opening it after a correction says which figure moved instead
  of quietly reporting different numbers. Share codes carry it too
- `E7-x` **Sugiyama's missing phase** — edges that skip a column are now broken into dummy
  vertices before the barycentre sweeps, and each sweep is scored by counting the crossings
  it leaves rather than assumed to help. On a fixed 364-graph corpus: 209 crossings before,
  176 after, locked in by `test/canvas/crossings_test.dart` as a ratchet
- `E3-4` **Whole buildings** — `asBuilt` re-reports a solved build with whole critters,
  plants and Duplicants. A machine you half need idles and the "busy" figure already says
  so; a Hatch does not, so the spare one's rock and coal are now stated where the rounding
  happens
- `E4-31` **Wild plants** — every crop has a wild twin: no water, no fertiliser, a quarter
  of the speed. Grazing follows from it, since growth is already an item — one Glo Squid
  takes two farmed Tublia or eight wild ones, which is the wiki's own figure
- `E4-21` **Wild versus groomed** — every ranched critter now has a `(wild)` twin sitting
  next to it in the palette: no grooming, no Duplicant time, a tenth of the eggs, and no
  fibre or plastic if a station was what took it off them. A wild ranch makes the same coal
  from the same rock for none of anybody's time, which is the trade the app now shows
- `E4-35` **Three more crops** — Pincha Pepperplant, Thimble Reed and Nosh Sprout, each
  with a grazed twin where a critter eats it. That closes the pepper bread chain: two
  crops, a Gas Range and a crew, with the field coming out far larger than the pepper patch
- `E4-34` **Cooking** — the Gas Range, Deep Fryer and Sushi Bar join the Electric Grill,
  so a kitchen can be planned from the crop to the crew, gas burned and Duplicant time
  included. The mass-balance audit caught the Gas Range on the way in, exactly as intended
- `E10-9` **The numbers on the wires are clickable** — most rates are read on the canvas,
  so that is where switching per-second and per-cycle should be reachable. Clicking the
  number switches the units; clicking the wire anywhere else still selects it
- `E10-6` **The cursor lands where the fix is typed** — clicking a suggestion selects the
  node, travels to it, and puts the cursor in its amount field, so the number can be typed
  straight away. Selecting a node the ordinary way does not steal the cursor
- `E12-7` **Two builds on one canvas** — an amount now belongs to the build it was given
  to, where a build is whatever is wired together, so two chains sharing a page no longer
  wipe each other's numbers. Wire them together afterwards and they become one build with
  two amounts, which the solver rightly calls a contradiction
- `E12-8` **⌘C / ⌘V for nodes** — copy a selection into the same canvas or another build.
  Wires inside the selection come along, wires leaving it do not, and ids are rewritten on
  arrival so a build pasted into one it grew from cannot join up things nobody joined
- `E7-12` **Tidy a selection** and `E7-14` **Fit a selection** — part of a build arranged
  by hand survives tidying the rest
- `E7-15` **The view glides** when it travels to find a node, so which way it went is
  visible. Touching the canvas stops it: the hand always wins
- `E7-11` **Minimap** — once a build outgrows the window there is no way to tell from the
  middle of it what else exists or which way it lies. A chart in the corner shows the whole
  build with the window marked on it; click or drag to travel, and the zoom is left alone
- `E12-6` **Selecting a node goes to it** — being told which node is the problem is no
  help if finding it means hunting a canvas larger than the window. Selecting one thing
  brings it into view, leaves the zoom alone, and does nothing when it is already there
- `E12-5` **The scale warning speaks English** — it said "Not enough pins: spare could be
  any amount", which used a word the app never teaches and named a node by its internal
  id. It now explains that nothing sets the size of the build, names things as the palette
  does, and uses the same phrase as the buttons under it. Tests assert the message avoids
  "pin", "node" and "underdetermined" and never quotes an id
- `E12-4` **A dragged card follows the pointer** — three faults compounded: the zoom
  correction was applied twice, the grid snapped every frame and threw away whatever had
  not yet reached a line, and the drag was measured from where the gesture was recognised
  rather than from where the pointer went down. Only the last is visible at 100 % zoom,
  which is why it survived so long
- `E12-3` **Nodes away from the origin can be clicked** — the node layer was laid out at
  the size of the window, so anything at negative coordinates or beyond the window's width
  in world units was painted but never hit-tested. Flutter paints outside a box when told
  to and never hit-tests outside one, and `OverflowBox` fixes only the first half of that
- `E12-2` **Zoom that can be found** — a trackpad pinch did nothing at all, and the only
  way to zoom was ⌘-scroll, which nothing announced. Pinching works, ⌘= / ⌘− / ⌘0 work, and
  there are buttons on the canvas showing the current percentage
- `E12-1` **Saved builds survive the data changing** — splitting the plants removed ports
  that saved pipelines were wired to, and the canvas threw on every frame trying to draw
  them. Drawing now tolerates anything it cannot resolve, and a repair pass moves a node to
  the process that still has its ports rather than cutting the wire, saying what it changed
- `E8-3b` **Mass-balance audit** — every process is checked for matter in versus matter
  out. The game does not conserve mass, so the rule has exceptions, but each one is now
  named and reasoned in a table that a test keeps honest in both directions: an unexplained
  imbalance fails, and so does a stale entry describing a process that balances again.
  Running it over the whole database found no errors, which after a day of corrections is
  worth knowing
- `E10-5` **Problems you can act on** — "not enough pins" now offers the free nodes as
  buttons that select them, instead of naming internal ids in a sentence and leaving you
  to find them. Nothing is silently dropped either: extra issues sit behind a count that
  expands
- `E3-5b` **Floor space** — every building's footprint was recorded and never shown. A
  build now reports the tiles it needs, per node and in total, counting whole buildings
  because half an Electrolyzer takes as much floor as a whole one. That empties the list
  of things the database knew and the app did not say
- `E1-7` **Temperatures shown** — every port that declares one now says it, and a flow past
  the 75 °C nearly everything overheats at is called out. The wording is careful: it is an
  invitation to look, not a prediction, since whether something cooks depends on what the
  pipe runs past and this model cannot see that
- `E11-3` **Pumps** — one generated per fluid, the way sources and sinks are, since a pump
  is the same building whatever it moves. Their power is the largest hidden cost in a
  plumbed build: two gas pumps to fill a single gas pipe is 480 W before anything has been
  done with the gas
- `E11-1` **Conduit capacity** — a ratio that balances on paper is unbuildable if the flow
  between two nodes needs three pipes. Every wire now says what carries it: liquid pipes at
  10 kg/s, gas pipes at 1 kg/s, conveyor rails at 20 kg/s, and the cheapest wire that
  stands the load. A flow needing more than one run is marked on the canvas, not just in
  the inspector
- `E5-3` **Share a build** — Copy code puts the open pipeline on the clipboard as one
  base64 line that survives a forum post; Paste build reads a code *or* raw JSON, since
  anyone handed a `pipelines.json` will paste that and be right to expect it to work. An
  import always lands under a fresh id, so someone else's build can never overwrite yours
- `E7-10` **Multi-select** — ⇧-click to add, ⇧-drag to rubber-band, and dragging any
  member of a group carries the rest. Delete takes the whole selection with its edges and
  pins, in one undo step, and the inspector summarises a group's power, heat and labour
  rather than showing nothing
- `E4-33` **The food chain** — Bristle Blossom, Dusk Cap, Waterweed and Sleet Wheat, plus
  the Electric Grill, so a crew can be fed end to end: wheat to grain to grill to
  Duplicants, with the cook's time counted. Oxygen, power and food are all plannable now
- `E4-36` **Harvested and grazed are separate processes** — a plant's growth is either
  eaten by a critter or harvested as a crop, never both, and offering both on one process
  let a farm be counted twice. Six plants split; a test now enforces that no plant
  publishes a crop and its growth at once
- `E3-7b` **Vented output ports** — "I have a geyser *and* twelve dupes, what is spare?"
  used to read as a contradiction, because a port something pulls from has to balance
  exactly. Marking it vented drops that equation and reports the leftover instead. The
  inspector offers it on exactly the ports where it changes anything, and the solver's
  diagnostics name them when a build comes out inconsistent
- `E7-9` **Auto-layout** — `Tidy` arranges the graph left to right: every node one column
  right of whatever feeds it, ordered within columns to keep the wires from crossing.
  Recycling loops are laid out by ignoring the edge that closes them, so a SPOM reads
  forwards and the returning wire doubles back. One undo step, then it frames the result
- `E4-29` **The remaining grazers, properly** — Mealwood, Arbor Tree and Pikeapple Bush
  seeded, and Drecko, Glossy Drecko, Pip and Flox switched from kilogram stand-ins to real
  growth links. The ratios ONI players already know now fall out of the model rather than
  being asserted: four Dreckos to three Mealwood, one Glossy Drecko to one, and five
  Mealwood to feed a Duplicant
- `E10-7` **Per-second ⇄ per-cycle** — click any rate, or the top-bar button, and every
  rate in the app switches together: mass to kg/cycle, power to the kJ a cycle delivers,
  and a trickle like one egg every six cycles to a number a person can picture. Capacities
  are exempt, since eight grooming slots is eight either way. The choice is remembered
- `E4-30` **Plant growth as a capacity link** — a grazing critter eats a *fraction of a
  living plant*, not kilograms off a pile. Growth is measured in percentage points of
  maturity per cycle, so a plant's growth *time* decides how many mouths it keeps: a
  4-cycle Starnacle offers 25 % a cycle and a Beakon eating 12.5 % takes half of it. Same
  mechanism as grooming, shearing and milking. Applied to Beakon/Starnacle,
  Glo Squid/Tublia and Gassy Moo/Gas Grass, which closes the Moo's missing input
- `E4-9b` **The Aquatic critter roster, complete** — Beakon, Slogo, Gildgo, Orehull,
  Glo Squid, Seaquine and Kelpole join Blowter. Their individual pages carry rates even
  though the summary table does not, which is how they came to be wrongly written off.
  Brings in a `milking` service link alongside grooming and shearing
- `E4-24` **The Frosty and Prehistoric Planet Packs** — 21 new elements, the Peat Burner,
  the Ice Liquefier, the Wood Heater, Alveo Vera, and five critters. Notable: the Spigot
  Seal makes ethanol without a distiller, the Blum Lumb is two Duplicants' worth of oxygen
  on legs, the Dartle is renewable bleach stone, and the Shatter Flox eats abyssalite
- `E4-15` **Six more base-game critters** — Pip, Pokeshell (renewable sand without a Rock
  Crusher), Gassy Moo, Plug Slug, Shove Vole and Shine Bug, bringing the roster to 20.
  Where the wiki gives a diet but no conversion, the game-wide 50 % ratio is used and the
  process says so; where it counts food in plants or calories rather than kilograms, the
  input is left out and the description admits the mass will not balance
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
| E1-7 | ✅ | Temperature reported | ports carry a temperature and the app shows it; heat exchange is still not modelled |
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
| E3-4 | ✅ | Rounding modes | `exact` (fractional buildings, the true ratio) vs `whole` (ceil to integers, then re-report the resulting surplus/idle %) — both shown |
| E3-5 | P1 | Derived totals | total power draw / generation, net power, total heat kDTU/s, dupe labour, footprint tiles, raw inputs list, net outputs list |
| E3-6 | P1 | Bottleneck detection | which node caps the pipeline when a raw input is capped |
| E3-7 | P2 | Simplex / LP upgrade | let the solver *choose* the shares to maximise a target output or minimise a raw input, instead of user-set shares |
| E3-7b | ✅ | Vented output ports | a pulled port normally balances exactly; venting drops that equation and reports the excess |
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
| E5-3 | ✅ | Share a pipeline as a base64 code |
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
| E7-9 | ✅ | Auto-layout (layered / Sugiyama) |
| E7-10 | P2 | Marquee select, group move |
| E7-11 | P2 | Minimap |

## E10 — Panels & the pin interaction

| id | P | Task | Notes |
|---|---|---|---|
| E10-1 | P0 | Process palette | searchable, grouped by tag (oxygen / power / liquid / refining), click or drag to place. Sources and sinks listed per item |
| E10-2 | P0 | **Pin control** — the headline | select a node → "I have ▢ of these" (buildings) or "▢ g/s" (source/sink). Pinned node wears a lock badge; clearing it is one click |
| E10-3 | P0 | Inspector | selected node: every port with its solved rate, what is connected, power, heat, uptime, and the `unverified` warning if the data ever carries one |
| E10-4 | P1 | Summary bar | net power, total heat, raw inputs, net outputs, dupe labour — always visible |
| E10-5 | ✅ | Problems panel | solver issues as a real list: underdetermined (with the "pin one of these" nodes as buttons), inconsistent, shortages |
| E10-6 | P1 | Edge inspector | pull ⇄ push toggle and the share slider, explained in words rather than jargon |
| E10-7 | ✅ | Per-cycle ⇄ per-second toggle |
| E10-8 | P2 | Templates: start from SPOM, petroleum boiler, coal farm |

## E8 — Quality

| id | P | Task |
|---|---|---|
| E8-1 | P0 | Unit tests for every solver path (DAG, cycle, underdetermined, inconsistent, shortage, surplus) |
| E8-2 | P1 | Golden real-world scenarios: SPOM, petroleum boiler, oxylite chain, coal farm — with hand-checked expected numbers |
| E8-3 | ✅ | Property test: any solved graph satisfies mass balance within ε |
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
