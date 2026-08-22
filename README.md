# ONI Pipeline Planner

Plan *Oxygen Not Included* production chains: draw the pipeline, **pin one node**
("I have 3 Electrolyzers", "my geyser gives 2 kg/s of water", "I want 1 kg/s of
oxygen"), and every other building, flow, watt and kDTU scales to match.

## Layout

```
packages/oni_engine/   pure Dart — model, solver, game data. No Flutter.
app/                   Flutter app (macOS, web, iOS, Android).
docs/USING.md          how to use the app, and what it deliberately does not know.
docs/SOLVER.md         how the solver works, decided before it was written.
docs/PERFORMANCE.md    how it was made eight times quicker, and how to do it again.
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

## Oxygen, power and food

All three of a colony's problems are plannable. Food runs the whole way: Sleet Wheat makes
grain, an Electric Grill makes Frost Buns out of it, and Duplicants eat the calories — with
the cook's time counted against your Duplicant budget like any other labour.

A plant comes in two forms, harvested and grazed, because its growth is either eaten by a
critter or taken as a crop and never both.

## When it cannot work it out

The commonest thing a pipeline needs is another pin, and the app now offers the nodes
worth pinning as buttons — click one and it is selected, with the field that fixes the
problem in front of you. Other complaints sit in the same strip, and any that do not fit
are behind a count rather than dropped.

## How hot is it?

Where the game fixes a temperature — an Electrolyzer's 70 °C gases, a Water Geyser's 95 °C
water, a Steam Vent's 500 °C — the port says so, and anything past the 75 °C most buildings
overheat at is called out. That is an invitation to look rather than a prediction: whether
something actually cooks depends on what the pipe runs past, and this model cannot see that.

## Can it actually be built?

Balanced ratios are not the whole answer: a gas pipe carries only 1 kg/s, so three
Electrolyzers' worth of oxygen needs three of them. Select a wire and the inspector says
what carries it — pipes, rails, or the cheapest wire that stands the load — and any flow
needing more than one run is marked on the canvas as `×3`.

Pumps are in the palette too, one per fluid. Their 240 W each is the largest cost most
builds forget: filling a single gas pipe takes two pumps and 480 W before the gas has been
used for anything.

## Sharing a build

`Pipelines` → `Copy code` puts the open build on the clipboard as a single base64 line
that survives being pasted into a forum post or a chat message. `Paste build` reads one
back — or raw JSON, so a `pipelines.json` someone sends you works too. Imports always land
under a fresh id and never overwrite what you already have.

## More than one build on a page

An amount belongs to the build you gave it to, where a build is whatever is wired
together — so two chains sharing a canvas each keep their own scale. `⌘C` and `⌘V` copy a
selection, into the same canvas or a different build entirely.

## Working with more than one node

⇧-click adds to the selection, ⇧-drag rubber-bands a region, and dragging any member of a
group takes the rest with it. Delete removes the lot — nodes, their wires and their pins —
in a single undo step. The inspector totals a group's power, heat and Duplicant time.

## Getting around the canvas

A minimap in the corner charts the whole build with your window marked on it — click or
drag it to travel. Selecting a node from anywhere else, such as a problem in the banner,
brings it into view on its own.

Scroll to pan, pinch or ⌘-scroll to zoom, ⌘= and ⌘− and ⌘0 if you would rather type, and
buttons in the corner of the canvas that always work. The percentage between them is a
button too: click it to go back to 100 %.

## Tidy

`Tidy` in the top bar arranges the graph left to right — every node one column right of
whatever feeds it, ordered within its column to keep the wires from crossing. A recycling
loop is laid out by ignoring the edge that closes it, so a SPOM still reads forwards and
the returning wire doubles back on itself.

## Per second or per cycle

Click any rate — or the button in the top bar — and every rate in the app switches
together. Pipes and vents are sized per second; the wiki, the game's tooltips and most
questions worth asking are per cycle. Mass becomes kg/cycle, power becomes the kilojoules
a cycle actually delivers, and one egg every six cycles stops reading as `0.00`. Capacities
like grooming slots are left alone, because eight of them is eight either way.

## Grazing, grooming and shearing are links too

Not everything that flows is a material. A critter occupies one grooming slot and a
station supplies eight; a grazing critter eats a *fraction of a living plant* rather than
kilograms off a pile.

Growth is measured in **percentage points of maturity per cycle**, which is what makes the
sums work: a domesticated Starnacle ripens over 4 cycles, so it offers 25 % a cycle, and a
Beakon eating 12.5 % takes half of it — one plant keeps two Beakons. Plant a slower crop
and the same critter needs more of them. Wire the two together and the farm sizes itself
from the herd, with no arithmetic and no extra pin.

## A ranch is not free

Critters lay eggs, drop meat over their lifespan, and cost 12 s of Duplicant time each
per cycle to keep groomed. The summary bar reports that labour in seconds and in whole
Duplicants, so twelve Hatches read as 144 s — a quarter of somebody's day.

## Geysers are not constant

A geyser's shipped rate is a *lifetime* average at a typical roll. The real one in your
world picked its own numbers when the map was made: it is active between 40 % and 80 % of
a dormancy cycle that runs 25–225 cycles. Select a geyser and choose worst, typical or
best to see what your build survives on, or set them all at once from the top bar. Better
still, send a Duplicant with Field Research and type the exact percentage in — the panel
shows what it yields as you type.

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

Covers the base game, Spaced Out!, **The Aquatic**, **Frosty** and **Prehistoric Planet
Packs** — 104 items and 83 processes. Every process is
checked against [the wiki](https://oxygennotincluded.wiki.gg) and must carry either a
`verified` or an `unverified` tag — a test enforces it, an `unverified` process has to
explain what is doubtful, and the app warns you when you select one. Batch buildings
(Rock Crusher, Metal Refinery) are stated as continuous rates — 100 kg per 40 s
operation becomes 2500 g/s, with the duplicant's time booked as 600 s/cycle.
