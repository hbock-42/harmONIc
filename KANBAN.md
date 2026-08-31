# harmONIc — Kanban

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
| `P3` | Waiting on something outside this repo, usually a figure nobody has published |
| `spike` | Research / decide, output is a written decision, not code |
| ✅ | Done. The board below says what was actually built; the epic tables say what each id *is* |
| ❌ | Decided against. The row says why, because "we thought about it and said no" is worth keeping |

Every id has exactly one row in its epic's table and, once it is finished, one entry on the
board. Anything new gets an id from the *next free number in its epic* — E12 and E7-14 were
each handed out twice, and both took a while to notice.

---

## Board

### 🧊 Backlog

Everything not pulled into **Ready**. Grouped by epic below.

### 📋 Ready (next up)

**Canvas and interaction**

**Things the model cannot yet say**

- `E4-21b` Glo Squid and Seaquine wild twins, once somebody checks in game which of
  their outputs the milking station takes and which they give off anyway


**The app demonstrating itself**



**Game data**


**Data still to gather**


- `E4-35c` The plants that want a pollinator: a Sweatcorn Stalk sets fruit only when a
  Mimika or a Divergent visits it, and how often that happens is a fact about your base
  rather than about the plant. Its water is unpublished as well
- `E4-26` The rest of both packs: Jawbo (yields unpublished), Rhex (eats other critters,
  which a flow model cannot express), Gnit and Mimika (produce nothing), and the regular
  Lumb (its peat rate is stated nowhere). The Bammoth came out of this list on 2026-08-22,
  its page having been filled in since somebody last looked
- `E4-23a` The Beeta: five cycles of life, and the honey at the end of them. A rate is the
  wrong shape for that, which is why it was left out when its two neighbours went in
- `E4-28` Seaquine's ovolene rate. Checked again on 2026-08-22: the page says who may be
  milked and never how much
- `E4-25` Firm up the inferred 50 % conversion on the Pip: its page says what it eats and
  what it excretes without ever putting the two in one sentence. The other two are done —
  the Pokeshell's 50 % and the Shine Bug's 200 g of phosphorite a cycle are both published
- `E4-11` Nail down the unverified DLC rates: the Vulcanizer's latex and rubber rates, the
  Plant Pulverizer's cycle time, the Marine Drill's natural gas, Gum Palm's CO2. Checked
  again on 2026-08-22 — all four are still unpublished

### 🚧 In Progress

_(empty)_

### ✅ Done

- `E4-55` **The Dehydrator and Rehydrator** — eighteen recipes and nine dried foods, which
  un-strands the Dehydrator: it takes a dish now rather than calories, so something other than
  a Duplicant's plate can feed it. The nine the wiki lists are exactly the nine this Gas Range
  makes. Every figure already in the stand-in survived — 40 g/s of plastic, 20 of water, 5 of
  carbon dioxide — because they were all worked out from the same 300 s batch, 250 s drying and
  50 s of a Duplicant unloading. The test that pinned the old one is better now: calories out
  must equal calories in across all eighteen, in both directions, so an edit that invented a
  yield would be inventing food

- `E8-23` **The guide says how food works now** — a *Feeding people* section, because somebody
  wiring a grill to a Duplicant will find it does not connect and deserves to be told why
  before they find out. Checking the "what this deliberately does not know" section against the
  new model then found something worse: the Dehydrator takes **calories**, and since a dish
  became a material the only thing in this app that makes calories is somebody eating — so the
  only way to feed it is out of a Duplicant's plate. Written on the recipe, pinned by a test,
  and `E4-55` is P2 now instead of P3

- `E8-22` **The eating nodes keep out of the way** — looking at what yesterday's change did to
  the palette rather than only at what it did to the model. `E4-53` generated one node per
  food, and they were tagged `food`, so 55 ways to put something on a plate landed in the list
  of the 45 things that cook. The palette had already solved exactly this for pumps and
  filters, and said so in a comment two lines above; they get a group of the same kind

- `E4-52` **What grows the grill's ingredients** — mostly already here, and nobody knew: making
  a plant grow a crop instead of calories gave the Mealwood, Bristle Blossom, Dusk Cap,
  Waterweed and Pikeapple Bush back to the kitchen in one move. Two more added — the Megafrond,
  which eats 54 kg of chlorine a cycle out of the air for four grains, and the Spindly
  Grubfruit, which eats nothing at all and fruits once every four cycles. The wild Megafrond is
  deliberately absent: a wild plant in this data takes nothing, and that one takes chlorine, so
  it would be a lie in the shape of a convention
- **Every kcal figure checked against the wiki's food table** — 54 of them, three of which the
  parser could not match. Two were right and their rows were simply formatted differently.
  The third was wrong: mimillet is a seed a Mimika drops on dying and is inedible until it is
  toasted, and it had been given the *dish's* calories, so the app was generating a way to eat
  a seed

- `E8-21` **The audit that would have caught the Mush Bar** — five shipped errors were found by
  hand this week and not one by a test, so the newest of them got turned into one. No cooking
  building may make more than 100 g/s of food: a batch is a kilogram or two and the slowest in
  the game is the Smoker's 600 s, so 100 g/s is 60 kg a cycle out of one machine and the
  busiest thing here makes 20. Put the old figure back and it fails by name. It would not have
  caught the other four, which is worth admitting — the egg shell was 20× and the corallium was
  the wrong outputs entirely, and both are inside any plausible range

- `E4-56` **The Microbe Musher's recipes, and a bar that fed eight hundred** — going after
  Liceloaf and Tofu turned up the worst number found in this data yet: the Mush Bar's output
  was 1 666 g/s where it should be 1.67, a thousand times over, so one Musher fed eight hundred
  Duplicants. The recipe's own note said "one bar a cycle" the whole time; the figure did not.
  A dupe eats 1000 kcal a cycle and a bar is 800, so it takes 1.25 Mushers to keep one person
  fed, which is what it says now. Five recipes added besides — Liceloaf, Tofu, Berry Sludge
  twice over and Pemmican — and the Musher mixes with water or, in the Aquatic pack, mucin

- `E4-54` **The other food buildings' recipes** — Sushi Bar and Deep Fryer complete at four
  each, the Smoker at three. Veggie Poppers is one port with three crops on it because
  sweatcorn, pikeapple and spindly grubfruit are all 800 kcal a kilogram, so seven kilograms
  really is one rate — the first time that rule has been satisfied by a coincidence of
  nutrition rather than of mass. And five recipes had no `buildingId` at all, so the app could
  not offer to swap a Frost Bun for an Omelette on a grill it had already placed: the counts
  said 13 where the palette showed 14, which is how it was noticed

- `E4-39` **The Gas Range's twelve recipes** — it had one. Five of the other eleven take
  Electric Grill dishes and were unreachable until `E4-53` made a dish a material; those five
  are the reason that change was worth making. The Mixed Berry Pie is four recipes rather than
  one port with a choice, because its four berries go in at four different weights — 4 kg of
  grubfruit, 1 of gristle berry, 1.66 of pikeapple skewer, 6.15 of ovagro fig — and a port has
  one rate. Two tag errors fell out: Waterweed is base game and this called it Aquatic, and
  the Frost Bun had inherited *prehistoric* from its own recipe, which carries it only because
  megafrond grain is an alternative to sleet wheat. The pack audit caught both. And the Gas
  Range is 3×3, not the 2×2 this had — the same slip the grill had

- `E4-53` **A cooked dish is a material, not just calories** — 33 recipes stopped making
  calories and started making the dish, 37 foods carry a `kcalPerKg`, and the step that turns
  kilograms into a meal is generated per food the way a supply and a pump already are. The Gas
  Range's five unreachable recipes are reachable. The cost landed where `docs/FOOD.md` said it
  would — a node in the middle of every feeding chain — and somewhere it did not: two audits
  could never see a kitchen, because calories weigh nothing, and the moment food became matter
  both started shouting correctly. Food does not conserve matter, so the mass audit now looks
  away from anything edible, in one place, with the reason beside it

- `E4-51` **The Electric Grill's fourteen recipes** — it shipped with one, the Frost Bun, so a
  player looking for an Omelette found the building and not the dish. All fourteen now, at the
  50 s a batch takes. Ten ingredients had to be invented as items first — meal lice, mush bar,
  bristle berry, mushroom, raw egg, four fruits and megafrond grain — and each is a supply node
  until something here grows it, which is `E4-52`. Two of them are choices rather than recipes:
  three kilos of grain whether sleet wheat or megafrond, and Cooked Seafood out of fish fillet
  or raw shellfish at the same 1600 kcal. The footprint was 2×2 and the game says 3×2

- `E4-47` **The Rock Crusher's own list, and a rate that was 20× out** — reading the crusher's
  table properly, after a player's ceramic report, turned up two errors already shipped. Egg
  shell into lime was 100 kg a side; the game gives each lime recipe its own mass and this one
  is **5 kg**, so it was twenty times too generous. And corallium sat in the raw mineral class,
  which made it 100 kg of sand when it is 10 kg of lime and 90 of sand. Both fixed. The eleven
  rocks that crush into sand are now all offered — four of them were not items here at all —
  listed on the port rather than added to the class, because that class is also a Hatch's
  dinner. Three molt recipes added besides

- `E10-30` **A port says what it is measured in** — the recipe form asked for `g/s` whatever
  the port carried, so a Power output wanted grams of power and a Heat output wanted grams of
  heat. Reported with a screenshot and the caption *"5 grams of power, please"*. Every item
  already knows its unit — the whole app prints W and kDTU/s everywhere else — so the form was
  the one place ignoring it. A port with no item yet says "per second", because it does not
  know what it is measuring

- `E4-41`, `E4-50` **Pinpoket, Pinpoki, and the two things that take it** — the last of the
  chain a player reported as missing. 5 kg of refined carbon a cycle for a sixteenth of a
  Pinpoki; one Pinpoki is 100 kg of diamond in a Rock Crusher, or 7200 kcal of Uni in a Sushi
  Bar. The wild twin is the usual quarter with nothing to feed it, which the page bears out
  sideways: eight domestic plants keep a Marine Drill in diamond, and thirty wild ones. The
  Uni recipe is `unverified` for its time alone — the Sushi Bar's base craft time is published
  nowhere, so it uses the 50 s the Sushi Roll recipe here already assumed, and the two are
  wrong together or right together

- `E4-22`, `E4-49` **Two answers out of the game files** — a player read both off oni-db, which
  is generated from the game rather than written by hand, and it settled two rows the wiki has
  never been able to. The Grooming Station draws **no power**, which is what this modelled on
  the guess that silence meant none — a guess now retired into a fact. And the Seaquine eats
  3.1 kg of pearl a cycle and excretes **12 kg of slime**: this said carbon dioxide against
  that same 12 kg, the right number beside the wrong material. Both stay `unverified` for what
  is still open — the station's capacity is `E4-48`, and nobody has published the ovolene rate

- `E4-46` **The Rock Crusher takes ceramic** — the second report from a stranger, and right:
  the game crushes 100 kg of ceramic into 100 kg of sand and this refused it. Put on the port
  rather than in the raw mineral class, because that class doubles as a Hatch's dinner and a
  Hatch does not eat ceramic — which is `E4-47`, since the class is standing in for two
  different lists and matches neither

- `E4-42` **Biodiesel, the third fuel** — named on the Petroleum Generator's own page beside
  petroleum and ethanol, and it takes the same 2 kg/s, so it is a third choice on the same
  port. The material is here with its specific heat, which the two coolant audits insisted on
  before they would pass — every liquid this app moves has to know what it costs to cool.
  Making it is still out of reach: the Emulsifier has no published cycle time, the same wall
  Super Coolant hit, and the Husky Moo that milks it is not modelled

- `E4-44` **Plywood, and the press that makes it** — the fifth thing the Kiln burns, from a
  page Hugo found. It joins the **wood class** rather than being wired into recipes one at a
  time, because that is what it is: the wiki says it substitutes for wood one for one,
  "including all of those in Kilns and Smokers", and can be distilled to ethanol. Adding it to
  the class did all four at once and touched no recipe. Resin was on the unused-on-purpose list
  and had to come off it, which is that list working

- `E4-40` **The Kiln's other recipes, and what it does not cost** — reported: it will not take
  Gum Wood. Four recipes now instead of two, and the split follows the rule rather than
  convenience: firing clay costs 25 kg of coal *or* wood *or* peat, one rate, so the fuel is a
  choice on the port; making refined carbon costs 125 kg of coal, 200 of wood or 300 of peat,
  three rates, so it is three recipes. The wood one takes the class, so lumber and gum wood are
  both it. Both old recipes had their rates right and were tagged unverified over the wrong
  question — the page says crafting "does not require duplicant operation", so 600 s/cycle of
  Duplicant time came off both. Marking them verified is what dragged them into the
  mass-balance audit for the first time, where the Kiln's real losses now have their reasons
  written down. Plywood is the one fuel still missing, because the item itself is not in this
  data — `E4-44`

- `E4-43` **The Petroleum Generator burns ethanol** — the first report from somebody who does
  not know the app: *"I can't set petroleum generator to take ethanol either."* Quite right.
  The wiki gives one set of figures for every fuel it takes, so this is a port with
  alternatives rather than a second recipe, which is the rule that mechanism exists for — and
  the test that pins which ports claim alternatives made me say out loud that the rate really
  is the same before it would pass

- `E8-20` **Count the visits** — GitHub Pages says nothing about who came, so a script tag in
  `app/web/index.html` does: GoatCounter, cookieless, no identifier, nothing about the build in
  front of you, which is why there is no consent banner in front of any of it. It is also the
  first request this app has ever made to anywhere, so the README and the guide say so — the
  guide gained a **What leaves your machine** section rather than a footnote. The endpoint is
  not a secret and cannot be one: it is in the HTML of every page load, and all it permits is
  adding a count that anybody could add from the live site anyway

- `E8-7b` **The guide is a list of topics, not a wall** — reported by Hugo: three hundred lines
  and twelve headings arriving as one scroll, which is a document rather than something you
  look an answer up in. It opens on the twelve, each with a line saying what it is about, and
  reading one shows that one. Split at the headings the file already has, and the hint is the
  topic's own first sentence — so there is still exactly one copy of the guide and a topic list
  cannot drift from it. The old test proved every heading reached the screen and would have
  gone on passing while every *body* was hidden behind a click, so it opens each topic now

- `E15-14` **The words sit beside the thing, and Next with them** — reported by Hugo: the
  circle was too small, the narration was at the top of the screen while the action was in the
  middle of it, and it played itself. The bar is gone. A card sits beside whatever is about to
  be clicked, holding the line that describes it and the button that does it, so the words, the
  press and the thing are all in one place. The cursor is 40 px across and 60 while pressed.
  Nothing advances on a clock, which retired `E15-7`: there is no pace to tune when it waits
  for you

- `E15-12`, `E15-13` **The demo does what a person does** — Hugo, twice: it builds like magic
  and you cannot see where to click. He was right both times, and the second time was after I
  had "fixed" it by lighting a port dot. The cause was `E15-1`'s step model: a step was a call
  on the controller, so nothing was ever clicked. A step is an *intent* now — place this from
  the palette, click that dot and pick this — and who carries it out depends on who is
  watching. A test drives the model straight, as before, so `E15-3` still checks every figure.
  On screen, hands move a cursor to the thing, type into the palette's own search box because
  the row is otherwise below the fold, click, let the **real** port menu open, and choose a row
  out of it. Cause, then effect

- `E15-11` **A step shows where somebody would have clicked** — reported by Hugo: things
  appear and wire themselves up and you cannot see where the click was. A step points, at a
  port dot or at the palette row a node came from, and both were already able to light up —
  the dot is the glow a dragged wire uses for a port that would take it, the row is the one
  hovering uses. Considered `showcaseview` and `tutorial_coach_mark` and did not take either:
  they own the stepping, they dim the screen the demo exists to let you watch, and their
  targets have to exist before the tour starts, while every one of these is made by the step
  before

- `E15-10` **A demo that is no longer on screen stops** — switch tabs while one is playing and
  the next step used to build into whatever you switched to, then throw, because the node it
  meant to wire up was in the tab you left. A demo owns a tab and only while that tab is the
  one on screen; the player watches the workspace and lets go. Found by a probe, not a person —
  two measurements that day found nothing (73 µs for the wire labels, no overflow at 760 px)
  and the third found a crash

- `E8-19` **The third reachability sweep** — every public thing in `app/lib/` against every
  reader of it. Six had none worth having and went: `draftFor`, `legendOrder`,
  `WorkspaceController.isSaving` and the `_saving` field nothing ever read, `DemoRun.isAtStart`
  and `DemoRun.next`, and `isPublishedBuild`. Three of those were mine, written the same week,
  which is the point of doing this on new code rather than only on old
- `E12-9` **The port menu's empty list tells the truth** — the sweep went looking for what
  should call `draftFor` and found that the case it was written for cannot happen: every item
  has a generated supply and output, so all 1 415 ports have something to offer. What can
  happen is a search that matches nothing, and the menu answered that with "Nothing here makes
  water" — blaming the catalogue for the search box. It names the search now, and a test walks
  every port in the database to keep the claim honest

- `E15-9` **The canvas keeps up with the demo** — the finished geyser build is 1 152 px wide,
  more than the canvas has at any window this is used at, so the last things it placed happened
  off the edge: narrated and invisible. The player fits the view after each step, which is what
  `E15-2` said was its job and did not do. It also turned up a fault older than the demo —
  `fitToContent` did not stop a glide in flight, so a fit landing mid-reveal was overwritten a
  frame later. Pressing **Fit** while the view was still sliding did nothing at all

- `E15-8` **Offered once, on a first visit** — a line under the tabs with *Show me* and *No
  thanks*, and nothing plays until it is asked to. No new storage was needed: the workspace
  already returns whether it restored anything, and having nothing to restore is exactly what a
  first visit is. Which also means the offer is spent by the act of using the app — the next
  launch has a session, so the question never arises again

- `E15-3` **The narration is checked against the solver** — every demo run a step at a time,
  and every figure a line quotes matched against what the app is showing at that moment. The
  rule is digits: a number in figures is a claim, a number in words is prose, so a caption says
  which of its numbers it means. Compared as *written* rather than within a tolerance — the
  first version allowed 0.01 either way and let "1.39 kW" through, because 1 396.8 W over a
  thousand is 1.3968. Four wrong figures were tried against the finished version and all four
  fail

- `E15-5` **"Let it choose the split"** — act two, and the part no other calculator for this
  game does: one port with two lines out of it, an even split nobody asked for at 6.67 kg/s,
  and 10.00 kg/s once it is asked for the best. Four tests, and the one that matters is the
  last line's claim — that what the optimiser chose is written back onto the wires as ordinary
  shares, so every figure on screen still comes from the same solver as always

- `E15-6` **Where it is offered** — under the four starting builds on an empty canvas, and at
  the top of the guide's footer, which is where somebody lost already is. Below the builds
  rather than above them: somebody who came to draw something should not have to walk past an
  offer to be shown around first. An app built without a player offers nothing anywhere, which
  is what keeps the template tests from having to know demos exist

- `E15-4` **"What a geyser feeds"** — ten steps: a geyser, an Electrolyzer, a crew, one number,
  the red bar, the generator that turns it green, and the power wired back into the Electrolyzer
  so the build runs itself. Every figure it narrates was read off the
  running demo rather than typed in from the wiki, and two were wrong when checked: the bar
  prints **1.40 kW**, not 1 397 W, because it switches unit above a thousand. `docs/DEMO.md`
  said the same wrong thing and now does not

- `E15-2` **The player** — play, pause, Next while it is still playing, and leave. It runs in a
  build of its own, because a demo places nodes and pins amounts on the real controller and
  must not do any of that to what you were working on; leaving *deletes* that build rather than
  closing it, since a tab nobody made, left in the list, is litter. The clock is an injected
  seam, so the tests do not sleep — and the fake had to honour cancel, or a paused demo went on
  playing in the test while stopping everywhere else

- `E15-1` **The demo engine** — a demo is a list of steps; a step is one action on a real
  `PipelineController` and one line of narration. Nothing a person could not have typed, so
  every figure on screen still comes out of the solver — which is the only reason a demo of
  this app is worth playing rather than filming. A stage carries the ids of what earlier steps
  made, under names the demo chose, and throws by name when asked for one that was never made.
  Stepping through and running to the end reach the same build, which is the property the
  `E15-3` check will lean on

- `E14-3` **Report it, from inside the app** — at the foot of the guide, because that is where
  somebody already is when the app has confused them, and the toolbar has been out of room
  since before any of this. The link carries the version, the platform and the build itself as
  a share code, so a report opens here in one paste. Too big for a URL and the code goes to the
  clipboard instead — said out loud, since a clipboard that changes quietly has eaten something
- `E14-1` **The app says which build it is** — the commit, passed in by CI at build time.
  "Which version?" is otherwise the first question on every report, and the honest answer from
  a web app nobody installs was "whatever was on the site that day". A build from a laptop says
  `dev` rather than inventing a number
- `E14-2` **An issue form for a bug and one for an idea** — what is needed is asked for rather
  than hoped for, and the share code is the field that matters: the whole build opens here in
  one paste. The form says what it does and does not hold, so including it is a choice made
  knowingly. The idea form says two things first — a missing recipe you can add yourself
  today, and some things are missing on purpose

- `E10-29` **The shortcuts work on a keyboard without a ⌘ key** — reported by Hugo, from the
  toolbar's `⌘` button. The button was the small half: every *binding* said `meta: true`, so on
  Windows and Linux undo, redo, copy, paste and zoom were not mislabelled, they were missing —
  and the app went on the web four commits ago. Ctrl off-Apple, in the bindings, the labels and
  the card, chosen from the platform and injectable so a test can sit at either keyboard. The
  two buttons are `Keys  ?` and `Guide` now: `?` opened the keys and the `?` button opened the
  guide, which was two answers to one glyph
- `E10-28a` **The status text stops holding room it has no words for** — the same mistake as
  `E10-28`, one step on. Tight instead of loose moved the 158 px from a gap at the end of the
  bar into the status's own box, where it looked like empty bar beside a scrolled-off
  ALL GEYSERS. A flex child gets a *share*; this one wants its own width, capped at a share so
  a long status cannot squeeze the buttons out instead. The actions went from 515 px to 674
- `E10-28` **The toolbar's actions end at the right edge** — reported by Hugo. The node/link
  status text beside them was a *loose* flexible child: a Row gives such a child a share of
  the free space, it uses what it needs, and the remainder is left at the end — after the last
  button. 158 px of a text field's unused allowance. One word, `Flexible` to `Expanded`, and
  measured at two widths because the two cases are held right by different mechanisms
- `E10-27` **The app is published on every green push** — GitHub Pages, from the workflow that
  already runs the tests, with `needs: test` so a red build never reaches the web. Chosen over
  Google Cloud because the app is a static site with no backend at all: a bucket is pennies but
  HTTPS on a domain needs a load balancer at about $18 a month, and Pages is free. A first
  visit is ~4 MB gzipped, measured
- `E10-26` **"Use as little as possible" no longer empties the build** — reported by Hugo,
  following `DEMO.md`. Pin the ore supply, press the button, and every share went to zero: the
  minimum was real and useless, because the cheapest way to use no ore is to make no metal.
  `BestCase.runsNothing` refuses an answer that stops the build, the message names the amount
  that is actually missing, and both docs now say which end each question is asked from
- `E10-25` **An ore refines into its own metal, not any metal** — reported by Hugo: an Iron Ore
  supply into a Metal Refinery into a **Copper** output, and nothing objected. The output port
  says "refined metal" and copper is one of those. What was missing is that a class port with
  no choice made is not always undecided — the wire feeding it has decided. `settledItem` asks
  the wires, and the checked audit is that `follows` is the only thing in the data tying an
  output's identity to an input's: Metal Refinery, metal Rock Crusher, Smooth Hatch tame and
  wild, and a test that fails if a fifth appears untested
- `E10-24` **Picking a class-port building from the port menu works** — reported by Hugo: an
  Iron Ore supply, click the output, pick Metal Refinery, nothing happens. The menu asks
  whether a port *accepts* what is offered, which is class-aware; the click asked whether the
  two item ids were equal, and "metal ore" is not "iron ore". Two rules for one question, and
  the loose one drew the menu
- `E10-23` **The build that cannot balance says which port to fix** — reported by Hugo, who
  wired a Hydrogen Generator's power back into its Electrolyzer and got four identical
  paragraphs naming four ports. Three were innocent. Each candidate is now tried — vent it,
  solve again — and only the ports that actually rescue the build are named, ranked so that a
  "fix" which collapses every count to zero loses to one that leaves the build standing.
  Two smaller things found in the same screenshot: two wires between the same pair of nodes
  printed their labels on top of each other, and every count read `-0.00 ×`
- `E10-22` **The flow label sits in the middle of its wire** — reported by Hugo, who saw the
  numbers hugging the left of every wire. They were at 0.32 along, chosen only so the
  arrowhead at 0.62 had room. That is the painter's convenience showing through: a label off
  centre reads as belonging to whichever node it sits nearer. The label takes the middle and
  the arrow moves to 0.8, keeping the same gap between them
- `E10-21` **The arrows move the caret while you type** — reported by Hugo, typing into a
  geyser's rate. A node stays selected while its fields are being edited, so an arrow key
  meant for the caret moved the node instead, and the field never saw the press at all. The
  guard for this has existed since ⌫ was swallowing backspaces: every canvas shortcut stands
  down while a text field has the keyboard. The nudge was the one action that did not use
  it, because it is the one action with a class of its own
- `E10-20` **What your geyser actually gives** — spotted by Hugo. A geyser rolls two numbers
  when the world is made: how often it is awake, and how much it emits while it is. The
  shipped rate folds both into a lifetime average at a middling roll, and the only control
  was the active share — so somebody who had measured 2.4 kg/s with Field Research had to
  work backwards into a percentage to say so. There is a field for the rate now, in the unit
  the game reports it in. It is the same number as the percentage wearing a different hat,
  and setting either shows the other
- `E9-12a` **Holding ? makes no noise** — reported by Hugo within a minute of it shipping.
  macOS answers every key event nothing claims with a beep, and holding a key sends one
  press and then a repeat every few dozen milliseconds. The handler claimed the press and
  the release and let the repeats through, so the app sounded like it was refusing the key
  the whole time it was doing what was asked. Every event for that key is claimed now, and
  the test asserts what the framework reports rather than what the panel shows — the sound
  and the picture were never the same question
- `E9-12` **A card of the keys** — asked for by Hugo. Pairs rather than prose, three groups,
  eleven lines, in a column narrow enough to run your eye down. Two ways in and they behave
  differently on purpose: the toolbar button pins it open until dismissed, and holding **?**
  shows it only while the key is down — which is what you want mid-drag, when letting go of
  the mouse to close a panel is the thing you were avoiding. Held open it has no Close
  button, since there is already a key under your finger doing that job. The physical key is
  watched rather than the character, because ? is shift-and-slash and letting go of shift
  first would otherwise leave the card up
- `E9-11` **Change the recipe on a node** — asked for by Hugo, after finding it took 3.56
  petroleum Aquatuners to feed one turbine and wanting to try water. Each coolant is its own
  recipe because the rates differ — that is what a recipe is, and a port that offered them
  as a choice would be claiming they run at the same rate — but they are one *building*, so
  a node can be set to any of them in place. It keeps its position, its amount and every
  wire that still fits, and says how many did not: swapping an Aquatuner to petroleum drops
  the water line and nothing else. One swap is one undo
- `E13-9a` **Super Coolant** — asked for by Hugo, and missing for a plain reason: the
  Aquatuners are generated per fluid the database knows, and it did not know this one. It
  does now, at 8.44 DTU per gram per degree — twice water — which puts a single Aquatuner of
  it at 1 181 kDTU/s, more than a Steam Turbine can delete. One machine wants 1.35 turbines
  over it. The Emulsifier that makes it (1 kg of fullerene, 49.5 of gold, 49.5 of petroleum,
  for 100 kg) has no published cycle time, so the material is here to be had and cooled with
  and the recipe is not, which is written where somebody will look for it
- `E8-7a` **The guide closes when you click away** — asked for by Hugo, and the right ask:
  every other overlay in the app already does it, so the guide was the one that made you
  find its button. Clicking the dimmed area closes it; clicking or dragging the panel itself
  does not, which is the half worth a test since that is how somebody reads and scrolls
- `E5-1b` **Copying a build copies all of it** — importing one and duplicating one both
  rebuilt the pipeline by listing its fields, which is the same shape as the recipe editor
  bug from Tuesday: it works until somebody adds a field, and one had been added. Both had
  been dropping the recipe snapshot, so a copy lost the baseline that tells you a recipe
  moved underneath it. `copyWith` takes an id now and both use it
- `E5-1a` **A build from a newer app is refused** — the schema version has been written into
  every file since `E5-1` and never read. A build saved by a later version opened as though
  it were this format, and the round trip kept the version, so an older app would
  reinterpret a newer file and then save it still claiming to be newer. Refused now, with a
  message that says to update rather than that the build is corrupt — and one unreadable
  build costs you only that build, since the loader already skips what it cannot read
- `E3-6a` **An amount below nothing** — typing −5 into "I have this many" produced two
  errors, on the node and on its supply, both saying "check the edge shares". That is sound
  advice for the *other* way a count goes negative and no help at all when somebody typed a
  minus. It is refused where it was typed now, named on that node, in words about the
  amount. Zero is left alone: a build of no Electrolyzers eats no water, and saying so beats
  refusing to draw anything while a field is being cleared
- `E9-10` **The keys are written down** — the editor answers to nineteen shortcuts and the
  guide named three. Copy and paste of nodes, which is how part of one build gets into
  another, appeared nowhere at all: a shortcut nobody can find is a shortcut nobody has.
  The guide has a Keys section, the toolbar's Undo and Redo carry theirs the way the
  inspector's delete carries ⌫, and a test holds the guide to the map — removing a line
  from one fails against the other. Lifting the map out of the widget to make that possible
  dropped two bindings on the way, and the nudge test caught it; the honest fix was to put
  them back rather than to change the number the new test expected
- `E9-9` **The empty canvas offers the worked builds** — it explained what to do and gave
  nothing to press, while the four examples sat behind two clicks in a menu you would only
  open if you already knew they were there. That is the wrong way round for the one screen
  somebody sees before they know the app has any. Four buttons under the instructions, and
  pressing one opens it as a build of its own rather than writing over the blank one you had
- `E8-18` **Golden builds for the new data** — about fifteen recipes went in this week, each
  checked against the page it came from and none of them checked as a *chain*, which is what
  the golden builds are for: "a wrong rate three recipes upstream shows up here as a ratio
  somebody would notice in game". Two now. Twelve Sweetles eat 240 kg of sulfur a cycle,
  keep four Grubgrubs, and the press turns what they leave into 80 g/s of dirt and 120 of
  water with nothing lost. One Bammoth feeds forty Shine Bugs, which is the whole reason the
  patty is worth crushing. Halving the Sweetle's sucrose by one digit fails both
- `E5-6d` **An invented material can be got rid of** — inventing one is a keystroke and
  there was no way back: nothing ever removed it, and since it now brings a supply, an
  output and a pump with it, a typo left five entries in the palette permanently. It lives
  as long as a recipe of yours mentions it — deleting the recipe forgets it, editing it out
  forgets it, another of your recipes wanting it keeps it, and the app's own catalogue is
  never touched. A canvas drawn with one is repaired rather than broken, and the repair says
  what it removed
- `E5-6c` **An invented material says what kind it is** — the picker created everything as a
  solid without asking, which was invisible until the last fix gave custom materials the
  generated nodes every other material gets: a liquid you invented then got a conveyor rail,
  no pump, and no temperature, all of it confidently. Three buttons where the "Create…" line
  is — solid, liquid, gas — and it keeps solid as the default, because most materials are
- `E5-6b` **A material you invent is a material you have** — went looking to put a "write the
  recipe" button on the port menu's dead end, and asking *why* that list is ever empty found
  the real thing: an item added by hand got none of the generated nodes every other item
  gets, so a recipe using it could not be fed — not even with "I have some". The generator
  runs over the merged catalogue now, so an invented material has a supply, an output, and a
  pump if it flows. The button was the wrong fix and is not here; with that closed, an empty
  port menu can only mean a pack you switched off, and it says so instead
- `E9-8` **Searching the palette by material** — "what makes oxygen?" is the first question
  anybody asks a production planner, and typing it found the Oxygen Diffuser and the Oxylite
  Refinery and not the Electrolyzer, because the list matched names. It matches what a
  recipe carries now, and says which — *makes oxygen* under the name, since a Hatch turning
  up in a search for "coal" has to explain itself. Ordered by what you probably meant: a
  name, then what makes the stuff, then what eats it. The ranking is a function of its own
  so it can be tested as one, which is how the port menu's contextual answer has always
  worked and the palette now does too
- `E8-17` **One place for each rule** — three bugs this week were a rule that held in one
  place and not in its twin, so I went looking for rules written more than once. "This is
  the edge of a build" was spelled out as `kind == source || kind == sink` in nine places,
  which is nine chances to type `&&`. "This is counted rather than weighed" was asked four
  different ways. "This has mass" existed twice: once in the mass-balance audit, which is
  the thing that cares, and once as a constant in the solver that nothing had used since
  before the reachability sweep. Each is a getter on the model now, the audit asks the model
  rather than its own copy, and the dead one is gone
- `E8-16` **The undo stack grew for ever while you arranged a build** — it holds whole
  graphs and is capped at a hundred, and the cap was written into the ordinary edit path
  only. Starting a node drag pushes too, and that one had no limit: every drag added a copy
  of the entire pipeline and none of them ever left, so a session spent tidying a
  300-node canvas got heavier the longer it went on. One `_recordUndo` now, used by both,
  because the way to forget a rule twice is to write it twice
- `E8-15` **The rest of the per-frame work, measured then cached** — having found one scan
  running sixty times a second, I measured the others rather than guessing which were next.
  At 300 nodes: the connected components 300 µs, scoping the totals to one build 193 µs,
  and both are read at least twice a frame by the editor and the bar — about a millisecond a
  frame of walking a graph that had not changed. Cached, and dropped where the graph changes
  and, for the scoped one, where the *selection* does. The tests are for the dropping, not
  the keeping: cutting a wire makes three builds out of two, and selecting the other build
  must not show the first one's totals. Leaving one line out makes that fail
- `E8-14` **A scan that ran on every frame** — `hasASplitToChoose` decides whether to offer
  "get as much as possible", and the editor reads it while it builds. It asked every port
  how many edges touched it, and each of those questions walked the whole edge list: on a
  300-node build, about a million comparisons a frame for a boolean that is usually false —
  and *false* was the expensive answer, because nothing short-circuits it. Counting the
  other way round gives the same answer in one pass: two lines meeting at a port is a split,
  whichever end it is. Cached with the solve, and checked against the slow version on every
  shape, including a split at the *consumer*, which a one-ended count would miss
- `E8-13` **Every sentence the app says, read against what it does** — the method that found
  the last two bugs, done deliberately this time: all 134 user-facing strings in `lib/`,
  checked one at a time. Most were true. Two named a figure that lives in the engine as a
  constant and had been typed out by hand — "a geyser is active 40–80 %… the shipped rate
  assumes 60 %", and the 75 °C a bare building tolerates — so the app would have gone on
  saying the old number after somebody changed what it assumes. Both are written against the
  constants now, and a test holds the sentence to them: putting a literal back fails it
- `E5-6a` **Correcting a recipe stopped erasing what it is built from** — found by writing
  the message that told people to fix an unpriced building with + Recipe, and then looking
  at whether + Recipe could. It could not, and worse: `editable` did not carry the build
  cost across, so correcting a Metal Refinery's rates made a refinery built out of nothing
  and the shopping list lost 800 kg of rock without a word. It lost a Steam Turbine's
  1 000 °C rating the same way. Both come across now, and the form has a line per material
  with a button to add one, so the message is a promise it can keep
- `E3-0a` **The design doc caught up with the design** — `SOLVER.md` is what somebody reads
  first, and it had been describing Gauss–Jordan since the day that was replaced, along with
  a claim of "microseconds" for something measured at 14 ms. Both corrected, with the reason
  the elimination changed written where the algorithm is named. Four things that grew up
  beside the solve — temperature, valves, the simplex, as-built — now have a section saying
  why none of them is in the matrix. Prose cannot be tested, but vocabulary can: every
  outcome the solver can report and every kind of pin has to appear in the document, and
  that found `invalid` undocumented on the first run
- `E3-7f` **What the optimiser costs, and a theory disproved** — it shipped without a perf
  test, and `docs/CHOOSING-SHARES.md` had worried in advance that it would be slow. It is:
  about cubic, 24 ms at 200 nodes, 188 at 400, and 940 ms on a 500-node chain — a second of
  frozen window. The simplex's own comment said the fix would be the greedy pivot rule with
  Bland's as a fallback. That was tried and made *no difference*, within noise on every
  shape and a hair slower on some, so it was reverted and the comment now says so. The cost
  is not choosing the column; it is that every pivot walks a dense tableau. The next lever
  is the one that fixed the elimination — stop touching the zeros — and a guard now says
  when it is needed
- `E8-12` **Two more things the engine knew and nobody could read** — the sweep that found
  uptime, edge shares, the stockpile pin and the arrow keys, run again now that a fortnight
  of features has landed. `AsBuiltReport.drifts` has been computing what rounding costs the
  whole build since it was written, and only the per-node half ever reached a screen: a
  Hatch ranch eats 100 g/s more raw mineral than the figures beside it say, because the
  thirteenth Hatch cannot idle. It is in the bar now, and only when something was rounded.
  And `unpricedBuildings` — "a shopping list that quietly omits a building is worse than no
  list" — was never called: nothing shipped is unpriced, but a recipe *you* write has no cost
  until you give it one, so your own buildings were being left out of the total in silence
- `E5-9` **A browser keeps your builds now** — `localStorage`, behind the same interface the
  file store is behind, chosen by a conditional import so that neither half is compiled into
  the other. The seam has said "so a future web build can swap in browser storage without
  the rest of the app noticing" since it was written; this is the first time anything took
  it up, and nothing above the storage folder changed. Verified in a real Chrome rather than
  reasoned about — a test that writes a pipeline, opens a second store on the same name and
  reads it back, run with `flutter test --platform chrome`
- `E5-8a` **The README stopped claiming four platforms** — it said "macOS, web, iOS,
  Android", and what is true is that macOS is built and opened by `tool/smoke.sh` while the
  rest have never been run. Web is the interesting one: it *compiles*, because `dart:io` is
  stubbed there rather than absent, and then throws the moment anything touches a file — so
  a browser build would have lost the pipeline you were drawing at the first autosave. It
  now gets a memory store instead, which forgets on reload and says so, and the browser half
  is `E5-9`
- `E4-35b` **The plants that were never checked** — the row had an empty note, which is the
  worst kind: nobody could tell whether it was hard or merely unread. Read now. A Sporechid
  produces nothing a pipeline carries — a thousand zombie spores a second and eighty decor —
  so it is not a recipe at all. The Prehistoric food plants are a different problem: a
  Sweatcorn Stalk needs a Mimika or a Divergent to pollinate it, and how often that happens
  is a fact about your base's critters rather than about the plant. That half is `E4-35c`,
  with the reason written down
- `E4-38` **Food quality, decided against** — for the reason germs were. It changes no rate:
  a Duplicant eats the same kilocalories of a bad meal as a good one, and what quality buys
  is morale, which is a person rather than a flow
- `E8-11` **The guide, read as a reader would** — fifteen features in a fortnight were each
  appended to whatever bullet was nearest, and one bullet had quietly become three features
  and a broken line. Letting the app choose the splits now has a section of its own, the
  pack filters are explained where they are first mentioned rather than assumed, and the
  build-material advice is its own point. Two tests hold it: every section still reaches the
  screen, and nothing is written in Markdown the app's thirty-line renderer would hand the
  reader as a row of pipes. Adding a table and a link proves both bite
- `E11-9` **Valves** — the row said a cap is an inequality and this solver holds equations,
  which was true and stopped being the whole story when the simplex arrived. Two jobs from
  one number: the ordinary solver works out what the line *has* to carry and says when that
  is more than you have allowed — the figures do not change, because they are what the build
  needs — and the optimiser, which holds inequalities natively, works its answer out inside
  the valve instead. Cap the refinery line at 4 kg/s and "get as much as possible" comes back
  with 7 kg/s of metal rather than 10, and nothing has anything to complain about
- `E4-23` **Sulfur into dirt and water** — a Sweetle eats 20 kg/cycle of sulfur and gives
  half of it back as sucrose; a Grubgrub eats 30 kg/cycle of sucrose and gives all of it
  back as mud; a Sludge Press turns 150 kg of mud into 60 of dirt and 90 of water. Sulfur
  in one end, dirt and water out the other, and every step published. Two things it
  confirmed rather than assumed: the 50 % is agreed by three separate figures on the
  Sweetle's own pages, and the wild twins state their egg intervals — 4.5 cycles against 45,
  9 against 90 — so this app's "a tenth as often" convention is checked here instead of
  merely applied. The Grubgrub is two specs because its two diets have different rates,
  which is the Plug Slug rule again. It waited on nothing but `E13-8`
- `E4-9a` **Enriching uranium** — 10 kg of ore every 40 seconds, 2 kg of enriched uranium
  and 8 of depleted, balancing to the gram and running with no Duplicant at all. The
  leftover eighty per cent is the interesting part: the page says it builds "like any other
  Refined Metal", so it joined the class — and a Vulcanizer made of it and a Plug Slug
  eating it both fall out of that rather than being written anywhere. Uranium ore stays
  *out* of the metal ore class, because the game's own Crafting Station recipe reads "excl.
  Uranium" and a refinery does not smelt it: a centrifuge splits it twenty for eighty
- `E4-9d` **Rockets, decided against** — a launch is an event and this model holds rates. Fuel
  is spent per journey; a journey has a distance and a duration, and averaging one over a
  cycle is exactly what the Beeta's five-day life is already refused for. The engine pages do
  not publish a consumption figure in any unit at all, which rather settles it
- `E1-9` **The app builds and opens** — never checked anywhere until now. `flutter test` runs
  the widgets in a harness with no bundle, no plugins and no file system, which is exactly
  why the guide panel takes an injectable loader and the exporter an injectable directory:
  every seam that makes those testable also hides the real thing from the tests. CI cannot
  do it either, having no desktop. `tool/smoke.sh` builds it, diffs the guide *inside the
  bundle* against `docs/USING.md`, opens it and checks it is still up six seconds later. It
  is, and it was
- `E1-8` **Germs, decided against** — they change no rate. A Water Sieve passes 5 kg/s
  whether the water is clean or crawling, and what germs actually do — health, morale, a
  Duplicant off work — is a person rather than a flow. They also multiply and die over time,
  and this model has no time in it. The row said "keep a field so it can be added", which is
  precisely the unreachable-feature mistake `E10-16` to `E10-19` spent a fortnight undoing
- `E11-8` **Mixtures, decided against** — and the useful part is the experiment. A mixture
  cannot be an item, because its identity would depend on the answer and the answer on its
  identity; the honest version is a flow variable per edge *per item*, which is where a
  500-node build stops being 14 ms. Of the three things the row wanted it for, two are about
  layout, which this app does not model on purpose. The third looked real — two gases share
  one pipe in game and the app counts two — so I built it, then measured how often two lines
  of the same kind run between the same pair of nodes. On the four shipped templates: never,
  and structurally so, since an output node carries one item and the validator refuses the
  rest. A hundred lines that fire on no build anybody has drawn went in the bin
- `E3-7e` **LEAST, beside the figure it is about** — the last of the objectives, and the
  question was never the maths: least power, least heat and least floor are one coefficient
  per node. It was where to put them. A build-wide total has no node to hang a button on,
  and a total you dislike is the only place you would think to look for a way to shrink it,
  so the offer sits next to it in the bottom bar and appears only when something is divided.
  The three rarely agree — a Rock Crusher draws a fifth of a Metal Refinery and eats twice
  the ore — which is why they are three questions and not one. `E3-7` is finished
- `E3-7d` **"Use as little as possible"** — the mirror of the last one, and the question you
  ask once you know what you want: five kilograms of iron a second costs 7.5 of ore split
  evenly and 5 through the refinery alone. Which question a boundary node asks is a fact
  about the node rather than a setting — an output node wants the most of what it collects,
  a supply node the least of what it brings. With nothing asked of the build it answers
  honestly that the cheapest way to make nothing is to make nothing
- `E3-7c` **"Get as much as possible"** — 10 kg/s of ore feeding a refinery and a crusher
  gives 6.7 kg/s of metal split evenly, and 10 through the refinery alone. The app has
  always split what nobody divided evenly, which is a fair guess and rarely the best one;
  now an output node can be asked for the most the build can give. The part the plan had not
  foreseen is what makes it safe: the answer is written back as *shares*, the same ones
  somebody could have typed, so the numbers on screen still come from the solver that has
  always produced them and undo puts the whole thing back. It says "there is no most" for
  the two cases where that is the truth — an unpinned supply is infinite, and contradictory
  amounts are impossible
- `E3-7a` **A simplex, decided in writing first** — `E3-7` has read "let the solver choose the
  shares" since the solver was designed, and the first job was to say what that means. It
  cannot mean making the shares variables: `share·x` is a product of two unknowns and no
  simplex takes it. It means making the *flows* variables, which turns an output port's
  balance from an equality into an inequality — and that inequality is exactly the freedom an
  optimiser needs and the thing the current solver cannot express. `docs/CHOOSING-SHARES.md`
  is the decision; this is step one of three, the solver on its own, tested against problems
  whose answers were known before it existed. Beale's cycling example is in there, because
  every build with a loop in it is degenerate
- `E7-13` **A plain drag selects; space pans** — the gesture every other editor spends on
  selection was being spent here on panning, and a marquee needed ⇧. Held back for weeks
  because it changes something people already do, and settled by asking. The middle button
  pans too, on the raw pointer stream because a `GestureDetector` only ever sees the primary
  one, and two fingers still pan — three ways, so nothing is taken away without a
  replacement. The trackpad turned out to be the whole difficulty: its gesture arrives twice,
  once as a pan-zoom and once as a drag, and with the drag half no longer panning the pan had
  to move to the other one and the drag half be ignored outright
- `E4-17` **Recipes you wrote, handed to somebody who has not** — measuring a Smoker's cycle
  time in game is half an hour, and until now everybody who wanted it spent that half hour
  themselves. All of them go on the clipboard as one code, items included, since a recipe
  for a material the app has never heard of arrives broken without them. Pasting merges;
  theirs wins where the ids collide, and the count says how many of yours were replaced,
  because overwriting an evening's measuring without a word is the one unforgivable thing
  this could do
- `E13-8` **Spaced Out is a pack you can turn off** — the fourth, and the one the other
  three sit on top of, so having a planet pack implies it and not the other way round. It
  waited a long time on "a filter that hides some of a pack is worse than none", and the
  audit that fear deserved turned out to be small: nothing here models rockets or radiation,
  which is most of what the DLC is, so its whole surface in this database is liquid sulfur,
  sucrose, the Plug Slug and the Liquid Sulfur geyser. The geyser was found by the audit
  rather than by me — a base-game spec asking for a pack-only material is exactly what that
  check is for. Reading the Polluted Mud page for it also turned up a seventh food for the
  Sage Hatch
- `E13-8a` **Five pack tags were wrong** — read against the packs' own published lists
  rather than against what this app happened to meet where. Ice was Frosty because an Alveo
  Vera eats it and Abyssalite was Prehistoric although a Glo Squid is what excretes it here,
  and both are base game. Sucrose was Frosty because a Spigot Seal drinks it, and a Sweetle
  makes it with no pack at all. Amber and Resin are named on the Prehistoric pack's own list
  and carried the Aquatic tag — the app's own note beside Resin had said "Prehistoric" the
  whole time. A wrong tag hides a material somebody owns, which is the one thing a pack
  filter must not do
- `E4-26a` **The Bammoth** — filed for a year under "yields unpublished", and its page has
  them now: 30 kg a cycle of Plume Squash or Nosh Bean, the same either way, and all of it
  back as Bammoth Patty. A Rock Crusher splits 120 kg of that into 88 of clay and 32 of
  phosphorite, exactly, which makes a herd the renewable phosphorite a Shine Bug farm wants.
  How long that crusher operation takes is the one figure still missing, so the rate carries
  the doubt tag and the ratio — the part a ranch is sized on — does not
- `E4-25a` **A Shine Bug eats a fifth of what it was being fed** — 200 g of phosphorite a
  cycle, published, against the 1 kg placeholder that had been sitting there saying it was
  a placeholder. Its page weighs exactly one of its foods and counts the rest in calories,
  which is why the figure was missed. Eight bugs now want 1.6 kg a cycle rather than 8, and
  the doubt tag comes off both twins so the mass-balance audit checks them
- `E11-5` **What a hot line costs to cool** — 10 kg/s of 95 °C water carries 2 925 kDTU/s
  more heat than the same flow at 25 °C, which is five Aquatuners. The question as written
  — does this pipe heat the room it runs through — needs to know what the pipe is made of
  and what it runs past, and this model has no space in it. The size of the thing does not
  need any of that, and the size is what decides whether a line wants a steam room or
  nothing at all. A cold line is said the same way: cooling somebody already paid for
- `E5-7` **Export to a file** — the clipboard is how you send a build to somebody, and a
  share code lives until the next thing you copy. This is the one you can still open next
  year. No file picker and no dependency for one: it lands in the downloads folder, the way
  a browser puts a file there without asking, and the app says the full path. Exporting
  twice keeps both, because overwriting the archive you made yesterday is not what "export"
  means
- `E4-32` **A Pip grazes a share, not a plant** — 8.89 % of maturity a cycle, which is four
  fifths of an Arbor Tree or a sixth of a Thimble Reed. That the figure is the same either
  way is what makes it one recipe you pick the crop for. The grazed Thimble Reed has said
  "left for a Pip to graze" since it was seeded, to a Pip that could not eat it
- `E13-3` **A gasket is 50 kg of plastic** — the Crafting Station's page has the figure four
  buildings had been waiting on, and it is the same either way: 50 kg of plastic or of
  rubber, one gasket, 30 seconds. So a counted part now says what one costs beside it, and
  a Marine Drill asking for a gasket is a Marine Drill asking for 50 kg of plastic. The
  price is worked out from whatever recipe makes the thing, not written down a second time,
  so it says nothing where two recipes make one item or a recipe takes two things — half an
  answer here would read as a whole one. The station's other recipes make equipment, which
  is not a flow (`E11-7b` with it)
- `E4-27` **Cinnabar comes out of the refinery as a puddle** — 100 kg of ore is 100 kg of
  mercury, and mercury freezes at −38.85 °C while a refinery hands its metal back at 40 °C.
  The app had it making Solid Mercury, which is what a Frosty asteroid keeps in the ground
  and not what anybody's refinery produces. The rates were already right, because the
  generic recipes cover them; the element was not, and a build that thought it was moving
  ore on a rail was moving mercury down a pipe. Refined Metal is what a build cost asks for,
  so a liquid does not belong in it either way
- `E13-7` **Rot Pile** — what food becomes when it spoils, which is a Pokeshell's other
  food at the same 70 kg a cycle and a third thing the Compost turns into dirt. Spoilage
  itself stays unmodelled, so a rot pile arrives the way a geyser's water does: from
  outside. Reading the page also settled the Pokeshell's 50 %, which had been an inference
  from the critters that do publish theirs — the doubt tag is off and the mass-balance
  audit checks it now. Its slime went the other way: that is the Oakshell and the
  Sanishell, which this app does not model
- `E13-5` **A Sage Hatch eats six things at one rate** — dirt, slime, algae, fertiliser,
  polluted dirt or corallium, 140 kg a cycle whichever it is and all of it back as coal. The
  same rate is what makes it one recipe you pick the feed for, rather than six recipes or an
  invented "organic" class nobody could point at in the game. Prepared food is priced in
  calories instead, so it is a different recipe and is left out and said so
- `E13-4` **Galena is the one ore that is two things** — 87 kg of lead and 13 kg of sulfur
  out of 100, where every other ore comes back as one metal kilogram for kilogram. So it
  has a refinery and a crusher recipe of its own, and the generic pair now say out loud
  that they do not cover it: a port can exclude a member of the class it asks for. An
  exception, and meant to stay one — a class riddled with exclusions is a class drawn wrong.
  Lead came with it, and is the only refined metal you are worse off building with
- `E8-10` **The board is checked like the data is** — nine of twenty-eight entries in Ready
  were work the tables already called done, two of them for weeks. A board nobody trusts is
  worse than no board, so the disagreements it can have are a test now: an id in two tables,
  an entry with no row, a Ready entry its own row calls finished, a status the legend does
  not explain
- `E11-2b` **What to build a hot building out of** — an Electrolyzer is 200 kg of any metal
  ore, and at 95 °C only Gold Amalgam holds. Naming the whole overheat table was no use in
  front of a building that cannot choose from it. Two rows of that table were also wrong:
  nickel and zinc had been given +50 on the reasoning that a refined metal gets what the
  other refined metals get, and the game's table names five metals and stops
- `E9-6` **A light theme** — ☀/☾ on the toolbar, remembered between sessions. Not the dark
  palette inverted: every colour is chosen for the background it sits on, because a hue
  that reads on near-black is usually too pale to read on near-white
- `E9-7` **A cross to empty a search** — three search boxes, and getting back to the whole
  list meant holding backspace down
- `E11-7c` **Gaskets are things, not kilograms** — four of them is four, and a total in
  kilograms leaves them out rather than adding four to twelve hundred
- `E8-9` **Two more audits** — every building takes up floor (the Grooming Station and the
  Aquatic Milking Station took none, so a ranch under-counted its room), and every item is
  used or says why it is not
- `E8-8` **A rate-plausibility audit** — nothing measured in grams moves less than a gram a
  second, or more than ten pipes could carry, without a named reason. It is the check that
  would have caught the Marine Drill, and writing it found Gas Grass asking for liquid
  chlorine when the gas would do
- `E4-11a` **The Marine Drill was reporting a thousandth of its sulfur** — 250 kg per
  operation over a 1300 s cycle is 192 g/s, and 0.19 of them had been sitting in a field
  measured in grams since the day it was seeded
- `E4-37` **Two more Aquatic plants, and five that are not plants** — Sodicane and Clampum
  seeded. Bulbloom, Petta Pouf and Husha Cups are decorative, Mussel Sprout is wild-only and
  non-renewable, and Pinpoket's yield is quoted in a unit that does not match its growth
- `E11-6b` **Every fluid knows what it holds** — the last thirteen specific heats, read off
  their own pages. A fluid without one is dropped from any mixture it joins, so the test
  that used to list the gaps now asserts there are none
- `E8-7` **The guide is in the app** — a ? in the toolbar renders the same file, not a
  second copy of the words for a screen; two explanations of one thing disagree within a
  fortnight
- `E8-6` **A guide to using it** — `docs/USING.md`, written because every control in this
  app is obvious to whoever added it and to nobody else. Its last section is what the app
  does not know, which is where it is most misleading
- `E6-6` **Tabs** — the builds you have open, in a row, one click apart. Closing one puts it
  away rather than throwing it out; the menu still has everything you have ever drawn
- `E7-20` **Arrow keys nudge the selection** — one grid cell, eight with shift, and a run of
  presses is one undo rather than twelve
- `E10-18` **"I have this much in store"** — the third kind of pin could be shown and never
  made. Two tonnes of coal to last twenty cycles is 167 g/s, and the build is sized to it
- `E10-17` **Splitting an output between two lines** — a push line's share has been in the
  model since the solver was written with no way to set it, so the app was deciding for you
  and not saying so
- `E13-6` **The Plug Slug eats either** — any ore or any refined metal, 60 kg a cycle
  whichever it is, and it *generates*: 1 600 W for the 75 s of each cycle it is awake, which
  the app had no note of at all
- `E13-11` **A port that names what it will take** — "either peat or wood" is one recipe
  with two acceptable fuels now, rather than an invented material or two copies of the same
  recipe. The node picks, exactly as a refinery picks its ore
- `E10-16` **Part-time buildings** — a node can say it only runs half the time, which is how
  a real SPOM works. The solver has always known how; nothing in the app could say it
- `E13-10` **"Either peat or wood"** — one Smoker recipe per fuel. The first attempt invented
  a "Peat or Wood" material, which is not a thing the game has and turned up in the palette
  as a supply node nobody could own
- `E13-2b` **The Smoker and the Dehydrator** — brisket out of tough meat and wood, and a
  dryer that makes no food at all: its calories out are its calories in, and what it really
  buys is food that never spoils, which this app has no notion of
- `E8-5` **A benchmark that means something on a machine you do not own** — the perf test
  now asserts the *shape* of the cost as well as the clock: doubling the nodes must not
  quadruple the time, which is what a return to the cubic elimination would do
- `E10-15` **Draw the supplies** — one press puts a supply or output node on every port
  nothing feeds or takes from, so a build's edges become things you can price, warm and
  point at rather than a line in the totals. One undo for the lot
- `E3-8` **What the next one buys** — a node says what going from three to four would cost
  and make, which is the question a ratio raises and never answers. It is a second solve,
  which the solver work made free
- `E13-9` **A cooler for every coolant** — the two written by hand are now generated from
  each fluid's specific heat, which reproduces both published figures exactly and gives the
  other twenty. A petroleum loop is as ordinary a thing to plan as a water one
- `E4-20` **Eggs are worth something** — the Egg Cracker turns them into food and shell, and
  a Rock Crusher turns shell into lime one for one. Twenty-four Hatches feed six Duplicants
  on eggs alone, which is the sort of thing a ranch is for and the app could not say
- `E11-2` **What a flow's heat rules out** — a wire carrying 95 °C water now names the
  coolest material that holds it and the range above, instead of only saying "hot". And
  molten glass at 1 942 °C is told plainly that nothing here will do
- `E11-4` **Filters** — one generated per fluid, the way pumps are. The separation itself
  cannot be modelled without a notion of mixtures, and what can be modelled is what it
  costs: a building, 120 W, and a pipe's worth of throughput
- `E7-19` **A passing wire keeps its lane** — the dummy vertices reserved a lane while the
  columns were sorted and it was forgotten the moment anything moved, so a node could
  straighten itself into the middle of a wire that was passing it. Lanes now survive to the
  end, and the layout counts wires-over-nodes as something to avoid: 1 266 down to 983
- `E7-18` **Nodes slide to meet their wires** — Sugiyama's fourth phase, which Tidy had been
  skipping: each node now sits where its heaviest wire runs flat, and a pass is kept only if
  it does not tangle anything. Both measures improved — 2 683 crossings to 2 431, and the
  sag down 15 %
- `E7-17` **Tidy knows where the wires attach** — the layout treated a node as a point, so
  two supplies feeding one node scored identically and fell back on the order they were
  created in. It now uses the port rows, and the cooling loop comes out crossing-free —
  the arrangement a person reaches for in ten seconds
- `E10-14` **The pipelines menu reads as five things, not one list** — foldable sections are
  rows you can press rather than captions with a triangle, the saved builds have a heading
  of their own, and every section is ruled off from the next
- `E10-13` **Saving a build as a node, explained where you do it** — a button called "Save
  as recipe" among the sharing buttons said neither what it did nor where the result went.
  It is its own section now, saying what will happen, and the result lands under "My builds"
  at the top of the palette
- `E2-8` **A build as one node** — save a solved build as a recipe and place it in a bigger
  plan. What crosses its boundary becomes its ports; what it does to itself stays inside,
  which is the whole point of a box. A snapshot, not a link
- `E5-8` **Copy the build as text** — the engine has been able to write a plain-text summary
  since before there was a canvas, and nothing ever showed it. Now it is a button, scoped to
  the build you are in, and it gained the materials and floor space it was missing
- `E10-12` **The summary bar fits any window** — "inputs needed" wrapped to three lines
  when squeezed and pushed the rates out of the bar entirely. The label holds one line and
  the bar scrolls sideways, checked at five widths down to 600 px
- `E10-11` **The toolbar is grouped** — Undo and Redo, then Tidy and Fit, then the units,
  with a rule between each. Evenly spaced buttons had been saying that changing the past,
  the arrangement and the units were all the same kind of thing
- `E10-10` **The totals say which build they are about** — two builds on one canvas were
  being added together, so a SPOM paying for itself could hide a refinery 1.2 kW in the
  red. Selecting anything scopes the summary to that build, and the bar says which

- `E9-5` **Glyphs instead of dots** — every item was a coloured dot, so the only difference
  between water and oxygen was hue. Each category now has a drawn shape as well, checked
  pixel for pixel against every other in a single colour
- `E10-8` **Start from a build** — four templates behind the pipelines menu, each one a
  shape people actually make and each checked by the golden tests. They carry no positions:
  the canvas lays them out on the way in, so what opens is what Tidy would have made
- `E8-2` **Golden builds** — the petroleum boiler, the oxylite chain, the coal farm and the
  SPOM, with every number worked out by hand first. Two of my hand figures were wrong, which
  is the entire argument for writing them down before running anything
- `E3-9` **The solver at scale** — a 500-node build solved in 120 ms against a 50 ms target,
  and the test written to prove it found why: Gauss-Jordan filled in the rows it had already
  finished with. Eliminating downward only and back-substituting took it to 14 ms.
  Written up in `docs/PERFORMANCE.md`
- `E0-4` **CI** — analyse and test both packages on push, and check the generated data still
  matches the JSON it came from

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
- `E11-6` **Temperature that travels** — specific heat seeded for the seventeen fluids a
  build actually plumbs, and a pass after the solve that carries temperature downstream:
  published figures win, everything else is the mass-and-specific-heat mixture of what
  arrives. A supply node is where it starts, and blank means blank
- `E13-2` **The cooling loop** — a Steam Turbine deletes heat, an Aquatuner only moves it,
  and both are now sayable: heat was always an item and a negative rate always made an
  input port, but nothing had ever used it. A build can be asked how many Aquatuners its
  own heat needs, and the answer is a number
- `E4-12b` **The recipe editor's item picker obeys them too** — and checking whether item
  pack tags were trustworthy enough to filter by found three that were wrong, plus supply
  and output nodes that inherited no pack at all
- `E4-12a` **The port menu obeys the filters too** — and, while there, learned about
  material classes: clicking a port that asks for Metal Ore now offers the ore supplies,
  which it had been silently refusing to
- `E4-12` **Palette filters** — packs and wild variants can be switched off, remembered
  between runs. Two thirds of the catalogue was content a base-game player cannot build.
  The header says how much is being kept back, so a filter set last week is not mistaken
  for an empty database
- `E7-16` **The view follows a drag off the edge** — hold a node, a selection, a rubber band
  or a half-drawn wire against the window edge and the canvas pans, faster the harder you
  press. The dragged thing keeps moving even while the pointer sits still, which is the
  half that makes it useful
- `E13-1c` **Classes applied where they were verified** — Filtration Medium (Deodorizer and
  Water Sieve take sand *or* regolith), a Hatch eats rock rather than one rock, a Smooth
  Hatch eats any ore and gives back the matching metal at 75 %, and the Ethanol Distiller
  burns wood whichever tree it came off. Plus a Rock Crusher metal recipe, and a
  duplicate-id guard after two shipped specs turned out to be invisible copies
- `E13-1b` **Naming the metal** — a node can say which member of a class it is using, and
  an output that follows an input takes it: copper ore in, copper out. Unset stays generic
  and feeds anything; chosen feeds only what it really is, and the wiring is checked
  against the choice rather than the recipe
- `E13-1` **Material classes** — a port can ask for "Metal Ore" and take any of them. It is
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
| E0-1 | ✅ | FVM pin | `.fvmrc` pins an exact stable Flutter version; `fvm flutter --version` works; `.fvm/` git-ignored except config |
| E0-2 | ✅ | Monorepo layout | `packages/oni_engine` (pure Dart, **no** flutter import), `app/` (Flutter), root `README.md` |
| E0-3 | ✅ | Lints + CI-ready scripts | `very_good_analysis` or `flutter_lints`, `dart analyze` clean, `dart test` runs |
| E0-4 | ✅ | GitHub Actions | analyse + test both packages on push, reading the SDK version from `.fvmrc` rather than repeating it |
| E0-5 | ✅ | `melos` or simple `tool/` shell scripts for multi-package commands | one command runs all tests |

## E1 — Domain model (the ONI vocabulary)

| id | P | Task | Notes |
|---|---|---|---|
| E1-1 | ✅ | `Item` | id, display name, `ItemCategory` (solid / liquid / gas / power / heat / critter / plant / dupe-time / other), base unit |
| E1-2 | ✅ | `Unit` + `Rate` | canonical internal units: **g/s** for mass, **W** for power, **kDTU/s** for heat, **count** for entities. Display conversion (g/s ↔ kg/s ↔ t/cycle) lives at the edge, never in the solver |
| E1-3 | ✅ | `Port` | `(item, ratePerSecond, direction: input\|output, optional: temperature °C)` |
| E1-4 | ✅ | `ProcessSpec` | id, name, kind (`building` \| `critter` \| `plant` \| `duplicant` \| `source` \| `sink`), ports, `powerDraw`, `heatOutput`, `dupeLabourPerCycle`, `footprint`, tags |
| E1-5 | ✅ | Operating modes | one building = several specs (e.g. Oil Refinery is one, but Metal Refinery has one spec *per* metal; Generators have "on demand" vs "100% uptime") |
| E1-6 | ✅ | `uptime` factor on a node | a building fed at 60 % runs at 60 %; solver works in "effective building-seconds", UI shows both `count` and `physicalCount = ceil(count/uptime)` |
| E1-7 | ✅ | Temperature reported | ports carry a temperature and the app shows it; heat exchange is still not modelled |
| E1-8 | ❌ | Germs / disease | decided against on 2026-08-22. Germs change no rate: a Water Sieve moves 5 kg/s whether the water is clean or crawling, and what germs do — health, morale, a Duplicant off work — is a person and not a flow. They also multiply and die over time, and this model has no time. "Keep a field so it can be added" is the unreachable-feature mistake this repository has spent a fortnight undoing |
| E1-9 | ✅ | The app builds and opens | `tool/smoke.sh`: build it as an app, check the guide really shipped in the bundle, start it and see that it stays up. Nothing else does this — a widget test has no bundle, no plugins and no file system |

## E2 — Pipeline graph

| id | P | Task | Notes |
|---|---|---|---|
| E2-1 | ✅ | `PipelineNode` | `id`, `specId`, `count` (the solved variable), `pin?` |
| E2-2 | ✅ | `PipelineEdge` | `fromNode.outputPort → toNode.inputPort`, carries one item, has a `share` ∈ [0,1] of the source port's output |
| E2-3 | ✅ | Auto-share | edges leaving the same output port default to an equal split; user can override. **This is what keeps the system square** — flows become a linear function of node counts only |
| E2-4 | ✅ | `Pin` kinds | `buildingCount(n)`, `itemRate(item, g/s, at a port)`, `itemStock(item, mass, over duration)` → converted to a rate |
| E2-5 | ✅ | Validation | edge item must match both ports; no duplicate edges; unknown spec ids; dangling pins |
| E2-6 | ✅ | Free ports | an input port with no incoming edge = **external supply** (raw resource you must provide); an output port with no outgoing edge = **surplus/vent**. Both reported, never an error |
| E2-7 | ✅ | Cycles | recycling loops (petroleum boiler, SPOM hydrogen return) must solve — the linear system handles them natively, add regression tests |
| E2-8 | ✅ | Sub-pipelines | a solved build saved as a recipe: its boundary becomes its ports, its totals become its figures, and it is a snapshot rather than a link |

## E3 — Solver (the heart)

| id | P | Task | Notes |
|---|---|---|---|
| E3-0 | ✅ | Write `docs/SOLVER.md` | the maths, decided before code |
| E3-0a | ✅ | Keeping `SOLVER.md` true | it claimed Gauss–Jordan for a fortnight after the elimination was rewritten and "microseconds" after it was measured at 14 ms. Corrected, and its vocabulary is checked: every outcome and every pin kind has to appear in the document that describes them |
| E3-1 | ✅ | Linear system build | Variables = node counts `x_n`. One equation per **fed** input port: `Σ_e share_e · x_src · outRate(src,item) = x_n · inRate(n,item)`. Plus one equation per pin |
| E3-2 | ✅ | Gauss-Jordan w/ partial pivoting | dense is fine (graphs are ≤ a few hundred nodes); detect rank, report `underdetermined` (needs another pin) / `inconsistent` (contradictory pins) |
| E3-3 | ✅ | Result object | per-node `count`, per-edge `flow` (g/s), per-item global balance, list of `Shortage` and `Surplus` |
| E3-4 | ✅ | Rounding modes | `exact` (fractional buildings, the true ratio) vs `whole` (ceil to integers, then re-report the resulting surplus/idle %) — both shown |
| E3-5 | ✅ | Derived totals | total power draw / generation, net power, total heat kDTU/s, dupe labour, footprint tiles, raw inputs list, net outputs list |
| E3-6 | ✅ | Bottleneck detection | which node caps the pipeline when a raw input is capped |
| E3-6a | ✅ | An amount below nothing | refused where it was typed, instead of arriving as two errors about negative node counts that blamed the edge shares |
| E3-7 | ✅ | Simplex / LP upgrade | decided in `docs/CHOOSING-SHARES.md`: the shares cannot be variables (`share·x` is not linear) — the *flows* have to be, with output balances becoming inequalities. Do it in three steps, and never as the only path |
| E3-7a | ✅ | The simplex itself | two-phase, Bland's rule throughout because every graph with a loop is degenerate; tested against textbook problems and against brute force on a hundred random ones |
| E3-7c | ✅ | One question, end to end | "Get as much as possible" on an output node. The simplex chooses the splits and they are written back as ordinary shares, so there is still one solver and one set of numbers |
| E3-7d | ✅ | Minimise a raw input | the same machinery from the other end: a supply node asks what the build could get away with using, and still delivers what was asked of it |
| E3-7e | ✅ | The objectives that are not a port | least heat, least power, least floor, offered beside the figure itself in the bottom bar — the only place somebody looking at a total they dislike would think to look |
| E3-7f | ✅ | What the optimiser costs | measured, guarded, and one theory disproved: about cubic, 24 ms at 200 nodes, and the greedy pivot rule the first comment recommended makes no difference at all |
| E3-7b | ✅ | Vented output ports | a pulled port normally balances exactly; venting drops that equation and reports the excess |
| E3-8 | ✅ | Sensitivity | "going from 3 to 4": what the next one buys and costs, worked out by solving the build again rather than by estimating |
| E3-9 | ✅ | Solver perf test | 500-node chain and 500-node fan, both under 50 ms; writing it found the elimination doing eight times the work it needed to |
| E3-5b | ✅ | Floor space | every building's footprint was recorded and never shown; per node and in total, counting whole buildings |

## E4 — Game data

| id | P | Task | Notes |
|---|---|---|---|
| E4-0 | ✅ | Decide data source | hand-curated JSON in `packages/oni_engine/data/` vs scraping the wiki. **Start hand-curated, seeded from the wiki, versioned per game update** |
| E4-1 | ✅ | JSON schema + loader | `items.json`, `processes.json`, `buildings.json`; strict parsing with helpful errors; unit-tested against the shipped data |
| E4-2 | ✅ | Seed set — oxygen | Electrolyzer, Algae Terrarium, Algae Distiller, Rust Deoxidizer, Oxylite Refinery, Deodorizer |
| E4-3 | ✅ | Seed set — power | Coal / Wood / Natural Gas / Petroleum / Hydrogen / Steam / Solar generators, Transformers, Batteries (self-discharge) |
| E4-4 | ✅ | Seed set — liquids | Water Sieve, Desalinator, Carbon Skimmer, Oil Well, Oil Refinery, Polymer Press, Ethanol Distiller |
| E4-5 | ✅ | Seed set — refining | Metal Refinery (per ore), Rock Crusher, Kiln, Glass Forge, Molecular Forge |
| E4-6 | ✅ | Seed set — food & farming | plants (per fertiliser/irrigation mode), Grill, Microbe Musher, Electric Grill, Gas Range |
| E4-7 | ✅ | Seed set — duplicants | O₂ consumption, CO₂ / dirt / polluted-water output, calories, so "20 dupes" is a pinnable node |
| E4-8 | ✅ | Ranching | critters: food in, meat/eggs/coal out, per-critter |
| E4-9 | ✅ | Spaced Out variants | split in two on 2026-08-22: the radiation half is `E4-9a`, the rocket half `E4-9d`. The base-game filter part shipped long ago as E4-12 |
| E4-9a | ✅ | Enriching uranium | 10 kg of ore every 40 s into 2 of enriched and 8 of depleted, which builds like any other refined metal. The Research Reactor is `E4-9c` |
| E4-9d | ❌ | Rockets | decided against. A launch is an event, not a rate: fuel is spent per journey, and a journey has a distance and a duration this model has no way to hold. Averaging a launch over a cycle would be the mistake the Beeta's five-day life is already refused for |
| E4-9c | P3 | The Research Reactor | its page gives the fuel (16.7 g/s of enriched uranium) and the waste (1.67 kg/s) and never the coolant between them, so the mass cannot be made to balance |
| E4-43 | ✅ | The Petroleum Generator burns ethanol | reported by a player: "I can't set petroleum generator to take ethanol either". The wiki gives one set of figures for every fuel it takes — 2 kg/s in, 2 kW out, 500 g/s CO2, 750 g/s polluted water — so it is a choice on the port, not a second recipe |
| E4-39 | ✅ | One recipe per food building is not enough | the Electric Grill had one of fourteen and the Gas Range one of twelve. Both complete. The Deep Fryer, Sushi Bar, Smoker and Dehydrator still have one each, which is `E4-54` |
| E4-40 | ✅ | The Kiln's other recipes, and what it does not cost | reported: it will not take Gum Wood. The wikitext, read raw after a summary of it came back self-contradictory, settles all of it — and settles the doubt the two existing recipes carried, which was never about their rates but about whether a Duplicant is tied to them. Nobody is |
| E4-41 | ✅ | Pinpoket, Pinpoki, and what eats it | reported as a chain: the plant, its fruit, Pinpoki → Diamond in the Rock Crusher, Pinpoki → Uni in the Sushi Bar. `E4-30` already has the plant waiting on figures; the two recipes are new |
| E4-48 | P3 | How many critters one Grooming Station keeps | eight is a fair guess and still a guess: a stable is 12–96 tiles and every species takes a different amount of room |
| E4-74 | P3 | The Critter Condo, and everything else that is partly grooming | +1 happiness where grooming and a brackene fountain give +5. Happiness is worth +225 % reproduction a point, so a Condo critter runs at 325 % against a groomed one's 1225 %: full metabolism and about a quarter of the eggs. This app has one grooming service and a critter's rates follow from having it or not, so a Condo cannot simply be a third supplier of it -- it needs either a per-port scale (the eggs only) or a third set of rates per critter, which is 65 more cards. The Airborne and Aquatic Condos are separate buildings again |
| E4-75 | P3 | Ink, and outputs that depend on a station | a Glo Squid gives squid ink because it is milked, and this app makes grooming and milking both required inputs -- so there is no way to say "kept but not milked", which is a real ranch that gives everything except the ink. The same shape as the Condo: an output that turns on and off rather than a rate that scales. Asked for as a toggle alongside grooming and Brackene |
| E4-45 | P3 | Whatever makes biodiesel | the Emulsifier's cycle time is unpublished; the Husky Moo would need a critter and a Milking Station this data does not have |
| E4-46 | ✅ | The Rock Crusher takes ceramic | reported by a player: the game crushes ceramic into sand and this refused it |
| E4-47 | ✅ | The Rock Crusher's own list, and a rate that was 20× out | eleven rocks make sand and this offered six; egg shell into lime read 100 kg a side when the game says 5; corallium was in the class and so made pure sand instead of lime and sand |
| E4-49 | ✅ | The Seaquine excretes slime, not carbon dioxide | the right number beside the wrong material — 12 kg/cycle was the diet's output all along |
| E4-50 | ✅ | Pinpoket, Pinpoki, and the two things that take it | the plant, the fruit, 100 kg of diamond in a Rock Crusher and 7200 kcal of Uni in a Sushi Bar |
| E10-30 | ✅ | A port says what it is measured in | reported with a picture: a Power port asking for grams per second. "5 grams of power, please" |
| E4-51 | ✅ | The Electric Grill's fourteen recipes | it had one. Thirteen added, ten ingredients that were not items here, and a footprint that was 2×2 where the game says 3×2 |
| E4-52 | ✅ | What grows the grill's ingredients | most of them turned out to be already here: `E4-53` made the plants grow crops instead of calories, so the Mealwood, Bristle Blossom, Dusk Cap, Waterweed and Pikeapple Bush all feed the grill now. Megafrond and the Spindly Grubfruit added. What is left is `E4-57` |
| E4-53 | ✅ | A cooked dish is a material, not just calories | five of the Gas Range's nine recipes take Electric Grill dishes, and this app turns every dish into calories the moment it is made. `docs/FOOD.md` is the decision |
| E4-54 | ✅ | The other food buildings' missing recipes | the Sushi Bar and the Deep Fryer are complete at four each, the Smoker at three. The Dehydrator and Rehydrator pair is still unmodelled, which is `E4-55` |
| E4-55 | ✅ | The Dehydrator and Rehydrator | eighteen recipes, nine dried foods. It was raised to P2 by `E4-53`, which left the Dehydrator taking calories that only a Duplicant's plate could supply; it takes a dish now |
| E4-56 | ✅ | The Microbe Musher's six recipes, and a bar that fed eight hundred | its Mush Bar output was a thousand times too large, and had been since the recipe was written |
| E4-58 | ✅ | What the Gas Range's `<hr/>` meant | three errors from one misread: a Mixed Berry Pie needs its grubfruit *and* a berry, Curried Beans needs four Nosh Beans nothing was asking for, and two recipes that take grain never learned megafrond grain would do |
| E4-59 | ✅ | The same reading across the other four food pages | the Grubfruit Preserve was missing the 4 kg of sucrose beside its fruit, and the fish taco never learned the megafrond grain its neighbour the tempura already took. The Smoker, the Dehydrator and the Rehydrator have no `<hr/>` cells at all and came through clean |
| E4-60 | P3 | Seeds as items, and the two recipes waiting on them | the Musher's Pacu Treat is six of any seed, and the Spice Grinder (`E13-2d`) is a tenth of one. Neither can be written until a seed is a thing this app can carry, which is a question about the plants, not about the recipes |
| E4-61 | ✅ | Every calorie figure read back against its source | all 64: the 25 cooked dishes against the Electric Grill and Gas Range tables, 52 against the Food page, and the nine dried ones against the Dehydrator's own "6000 kcal in, six 1000 kcal packs out". Nothing was wrong. The pair's conservation is now a test, which is the one part of this a machine can keep doing |
| E10-46 | ✅ | A loose end is not a loose build | reported: adding a Power output to a solved build said "nothing sets the size of this build, so every amount in it could be anything" while every other figure was right and unchanged. True of a build with nothing given anywhere, false of one that has just gained a loose end. It names the loose one and says the rest is settled |
| E10-70a | ✅ | A drag frame places no figures either | self-inflicted and found by measuring the cost of an edit: the label placement was cached on the pipeline, which is a new object on every frame of a drag, so it ran sixty times a second -- 1.1 ms a frame at 41 nodes, 12 at 369, on the very path made cheap by not re-solving. Keeping the last answer costs nothing real: what is stored is a fraction along each wire and the painter applies it to whatever path the wire has now, and the text comes from the solution, which a move does not change. Pinned by a widget test that drags ten frames and checks both the solution and the placement are the same instances |
| E10-86 | ✅ | An input you can decline, and the output that goes with it | the wishlist mechanism, scoped down to the part that can be said exactly: Port.needsPortId names the input an output only exists because of, and PipelineNode.portsSwitchedOff says which the reader has declined. Landed in one place -- rateOf() is the single point where a port rate is decided, so the balance rows, the flow terms, the pins and every report honour it at once. Switchability is derived, not declared: a port is switchable exactly when some output needs it, so no flag can disagree with the data. Only the Glo Squid has one (milking -> squid ink); the Seaquine is milked and nothing depends on it because its ovolene rate is unpublished. Deliberately not covered: a rate that changes rather than an output that goes, which is the Condo |
| E10-85 | ✅ | Brackene, the Critter Fountain, and two Plant Pulverizer recipes | wishlist: "toggles for grooming, Condos, Ink and Brackene". Brackene needed no toggle -- grooming is already an item one building outputs and critters consume, so a Critter Fountain is a second source of it and every critter can be kept either way with nothing changed. 5 kg/cycle/critter, serving eight like the other stations (unpublished, same convention and same caveat). Four audits fired on the new liquid and each wanted something real: a build cost, a specific heat (4.1), an Aquatuner (generated once the SHC was there) and amber struck off the used-nowhere list, since its recipe now exists. Also plant_pulverizer_slime was tagged aquatic and is base game -- the reason phyto_oil looked pack-only. Deferred: the Sleet Wheat and Pincha brackene recipes, whose outputs the wiki gives only as a per-plant yield |
| E10-85b | ✅ | And the fountain saves the Duplicant time it exists to save | found by checking my own work: with a fountain wired up the ranch cost exactly the same Duplicant time as with a station, because the time is booked on the critter and nothing looked at where the grooming came from. The building's whole point, and the model could not express it. The test I wrote asserted the *fountain* booked no time, which was never in question. Labour cannot move to the station -- it differs by species, 12 s for a Hatch and 24 for a Drecko -- so ProcessSpec gained `unattended`, meaning what this supplies costs nobody any time, and a critter whose grooming comes only from such a thing books none. All or nothing: half a ranch on a fountain is a figure this app cannot stand behind. Unwired grooming still costs, because outside the build is a Duplicant until somebody says otherwise |
| E10-85a | ✅ | The Gleaner, so brackene has somewhere to go | 1 kg/s brackene -> 90 g/s brackwax + 810 g/s brine + 100 g/s CO2 at 75 C, 480 W, 8 kDTU/s, 800 kg refined metal, 4x4, base game (the Aquatic pack adds an ovolene recipe on the same building). Everything published, mass conserved, and it passed every audit first time -- brackwax is a solid so it wanted no Aquatuner. The end-to-end test failed once for a good reason: power is a port too, and adding 480 W to a kilogram of brackene is not a mass balance |
| E10-84 | ✅ | Bionic Duplicants, a fifth pack, and four more mistagged materials | wishlist item 1. Bionic Booster Pack needs only the base game, so implies nothing -- it is a sibling of spacedout, not a child. Bionic Duplicant: 100 g/s oxygen from a tank, 200 W (one 120 kJ power bank a cycle), 20 kg/cycle phyto oil, 47.3 kg/cycle gunk, no calories, no CO2. Worse: the "only a pack makes it" check I added yesterday was vacuous -- every item has a synthesised supply node, pump and filter, all untagged, so the escape hatch always fired and it found nothing. A maker now means something that creates the item rather than passes it through, and it immediately found six. Fixed: phyto_oil (Bionic then base game, tagged aquatic), electric_grill_frost_bun (base game, tagged prehistoric), dried_mixed_berry_pie (untagged, its pie is spacedout), nosh_sprout (base game, tagged frosty). Documented as exceptions: abyssalite, gold_amalgam, milking, phyto_oil. And a mistake of my own worth keeping: I tagged nosh_bean frosty by inferring from its sibling, which hid Tofu and Curried Beans; the older check caught it in a minute and the fault was the sprout all along |
| E10-83 | ✅ | Materials and geysers checked by DLC | wishlist items 2 and 3. The packs are a hierarchy, not a set: frosty, prehistoric and aquatic are packs for spacedout, siblings of each other. Written down and checked -- a recipe may use its own pack and what that pack implies, never a sibling. Found one: Swampy Delights (spacedout) cooked from bog_jelly tagged prehistoric, which is Spaced Out; the Prehistoric note on the wiki page is about the two critters that eat it, the same error the existing comment already records for phosphorite and lime. Plus the reverse (an item only a pack can make must carry that pack -- clean), geysers checked the same way, and a tag allowlist so a mistyped pack cannot silently make something base-game |
| E10-82 | ✅ | Wild and grazed are a switch, not a separate card | first piece of the testing wishlist: "toggles for grooming, Condos, Ink and Brackene, with same format as plants". Measured first -- 65 wild variants, every one with a tame twin, plus 20 grazed: 29 per cent of the catalogue was a duplicate differing by one switch. The row itself already existed for buildings (22 Aquatuners, one machine) and only ever looked at buildingId, which a critter has not got. Added a family field, computed by stripping _wild/_grazed until a real id is reached, so arbor_tree gathers all four of its forms; variantsOf keys on family ?? buildingId. The heading was hardcoded to "THIS BUILDING ALSO RUNS", which a Hatch does not do. Ids are untouched, so every share code ever written still opens. Found on the way: accepts() summary line had been stranded above variantsOf doc |
| E10-82a | ✅ | And the palette shows one row per family | the visible half: the list was nearly twice as long as it needed to be for no information. Which member to show is decided by the search rank -- empty query and every member ties, so the one whose id is the family wins; type "wild" and the wild one ranks better and is offered. So folding a card away can never make it unfindable, which was the thing to get right. Knock-on: an existing test measured the show-wild setting by counting Hatch rows and watching the number fall, which no longer happens because the list already shows one. The setting still decides whether the wild one can be reached at all, so the test asks that instead |
| E10-81 | ✅ | Two reported diets, both wrong | "Sweetles cannot eat liquid sulfur and you dont have the full hatch diet useable" -- both true. The Sweetle was wrong in words only: sulfur and liquid_sulfur are separate items with no group between them so accepts() already refused the wire, while the description said "solid or liquid, the same either way". Doing one thing and saying another. Added liquid_sulfur_freezing (115.2 C, 35 kDTU/kg from the geyser 165.2) so the build can be drawn. The Hatch was wrong in the model: raw_mineral held 6 of the 10 rocks, missing granite, igneous_rock, sandstone and insulite -- checked against the Rock Crusher sand recipes, which are the same ten and which shares the class, so both were short by the same four. Deliberately not added: dirt, sand, clay, regolith -- Hatch food but not crushable, so widening the shared class would have been wrong for the crusher; named in the description instead |
| E10-80 | ✅ | "Already spoken for" offers the remainder, and offers it as a button | reported as producer-driven zeroing an entire build, which is what an invalid solve looks like -- no node results at all, so every figure vanishes including the forty nodes with nothing to do with it. The advice offered a share out of the air or making the starved line producer-driven too, which on a fully claimed port only adds another claimant. It never named EdgeMode.rest, added for exactly this. IssueFix grew restEdgeIds beside producerDrivenEdgeIds; offered only when exactly one producer-driven line has no share, since a button that guessed which of several would be worse than none. Checked on the reported build: the button lands on the right line and takes it from invalid back to inconsistent, which is solution (1) the reporter found by hand |
| E10-79 | ✅ | When more than one port is over-committed, name the set rather than the wall | reported with a picture: 31 ports named, none marked. Two gates were wrong. The search was exhaustive over *pairs* and stopped at two, so a build wanting three vented failed it as surely as one wanting thirty; and it was skipped entirely past 20 candidates, which is a ceiling on count where the cost is what matters -- a solve of the reported 46-node build is 1.3 ms, so the search was affordable all along. Greedy now: vent whichever leaves the build least broken, hold it, look again, up to four. Scored by whether it balances at all, then by how many nodes are below zero, then by how many are at nothing -- and a build that vents its way to all zeroes still loses, the same rule the single-port pass already used. Exhaustive pairs stay first, being exact and cheap |
| E10-79a | ✅ | Verified against the build it was reported from | the reporter's original code arrived damaged in chat and their second paste of the same code decodes clean, which settles that the app is fine and the transport is not -- two characters changed, gzip caught it. On the real 42-node build it now says "no one port explains this: it takes two: Gum Palm's gum wood and Arbor Tree (grazed)'s arbor tree growth", which is exactly the pair they found by hand over an afternoon of bisecting. 35 candidates, so the old ceiling of 20 skipped the search entirely. Costs 36 ms against 20 on that build, all of it hints -- the solve itself is 0.2 ms -- and only on a build that is already broken |
| E10-78 | ✅ | An output node takes what it is given | asked directly after a CO2 output on a Vulcanizer threw negatives and the error panel own fix -- set it to the producer -- resolved it. The first line into an output was consumer-driven, so its flow was a free variable with no demand behind it, and an over-constrained build could settle it negative. connect already reasoned an output is "a bucket, not a customer" for the *second* line; the first now does too. One test changed and it changed for the right reason: the notice owning up to converting the group is not needed when there was no conversion. Kept for the case that still has one -- a line set to the consumer by hand -- and guarded by a test that an output can still size a build |
| E10-77 | ✅ | A wire carrying nothing no longer reads "-0.000000" | reported from a 46-node build. Two causes: the per-cycle figures were formatted with toStringAsFixed directly instead of through the rounding the per-second ones have always used, so the minus survived on a rounds-to-zero; and the digit escalation capped at six, which is enough to print float noise faithfully -- the very thing it exists to prevent, from the other side. Cap is four, which still covers the Hatch (wants three), and past the cap the digits are given back rather than piled on. Also the digits were chosen from the number before the divide-by-1000, so kJ/cycle picked six for a figure that then had none left. An existing test asserted "0.000000 g/s" while its own stated reason argued for the opposite; the assertion was the thing that was wrong |
| E10-76 | ✅ | Volcanoes, magma and the sour gas boiler | asked for on Discord with the right suggestion attached -- add the volcano, put the numbers in, use it in the arithmetic. Two items (magma 1.0 SHC, sour gas 1.898) and five processes. Volcano 1.2 kg/s at 1726.85 C and Minor Volcano half that, both from the wiki. The other three are not buildings, which is new: petroleum past 541.85 C becomes sour gas, sour gas at -164.5 C falls into 67 per cent methane and 33 per cent sulfur, magma freezing at 1409.85 C gives up 317 kDTU/kg. The heat figures are arithmetic from the specific heats already on the items, stated as such in the descriptions the way the Steam Turbine does. 1 kg/s of petroleum wants 2.59 kg/s of magma, so 2.16 volcanoes. Found on the way: sulfur was tagged aquatic and is base game, the same error the pack test already records against Phosphorite |
| E10-75 | ✅ | The build stays still when the message above it grows | reported: dragging a card over another made the banner say a card was buried, the banner grew, the canvas below it was pushed down and the whole build jumped 66 px -- and back when the message went. The canvas cannot tell a top edge that moved from a bottom edge that did by its size alone, and only the first should be compensated, or resizing a window from the bottom would scroll you somewhere. So it watches where the viewport actually sits on screen, in a post-frame callback since that is not known until the banner has taken its space, and shifts the view by what moved. Skipped mid-glide, or it would fight _travelTowards and land short |
| E10-75a | ✅ | And the message moved over the canvas, so there is nothing to correct | compensating after layout leaves one frame painted in the wrong place, which is exactly a flash -- reported as still flickering. The banner is in the canvas Stack now, where the find bar already was for the same reason, so the canvas never changes size. Opaque, since it is over wires rather than over the page background. The cost is that the top of the canvas is covered, and revealNode counted that strip as visible -- showing somebody a card by leaving it under the message that named it -- so the canvas takes an obscuredTop and both the visible test and the centring honour it. The test for that needed three cards: moving the buried one settles the problem and takes the banner with it |
| E10-74 | ✅ | A save that cannot be written is lost, not fatal, and the browser store is finally run | followed the coverage into storage: browser_store.dart did not appear in the report at all, having never been executed on any platform, and it holds every saved build for the primary way people use this. Comparing the two stores showed the asymmetry -- the browser one swallows a failed write with a comment saying why, the file one caught on the way in and not on the way out, and workspace_controller calls it unawaited, so a full disk was an unhandled error. The contract is on the JsonStore interface now so both are held to it. test/browser runs under `flutter test --platform chrome` in CI: the rest of the suite imports dart:io and would not compile there |
| E10-73 | ✅ | The checks for a build that could not have been made here | picked by coverage rather than instinct: engine 92.9 per cent, app 95.9, and the biggest single hole was validation.dart -- 47 lines of structural checks that had never once been run. They guard a share code hand-edited, written by a newer version, or damaged in transit, all three of which have happened. Duplicate ids, unknown recipes, uptime out of range, wires off missing nodes and ports, wires the wrong way round, amounts on cards that are gone. Each is checked twice: that it says something, and that solving does not throw -- and three more open the whole editor on such a build and assert no exception, since a message is no use if nothing is left standing to show it. Everything passed first time; the code was right and unexercised |
| E10-72 | ✅ | A random walk of edits, and three things that must hold | the sibling of E10-71, pointed at the editor rather than the solver: sixteen thousand random edits across the corpus -- pins, wire modes, shares, uptime, ceilings, venting, temperature, the optimiser, deletes, undo and redo -- checking that nothing throws, that a share code comes back field for field, and that an undoable edit is put back exactly by undo and again by redo. Found nothing, at 40 and at 80 steps a build, which is worth recording as a result rather than quietly deleting. One thing the first draft got wrong: undoing after every edit to check it kept the build within one step of where it started for ever, so it now redoes and walks on |
| E10-71 | ✅ | A build that feeds only itself no longer crashes | fuzzed the corpus through everything the editor asks for and 16 of 424 threw RangeError. The below-zero message names the ports drawing too hard, and when every node feeding a negative one is itself negative there are none -- _sentenceList did take(-1) on the empty list. The crash was the smaller half: the sentence would have read "more is being drawn from  than they make". It now says the loop has nothing coming into it from outside. The fuzz is kept as a test, and the roughing up matters as much as the corpus: the crash needed push and rest lines mixed in, a vented port, and an amount given. Found builds live under test/fixtures/found, since fixtures/ means codes as pasted before compression |
| E10-70 | ✅ | Flow figures no longer disappear behind cards | found by measuring, not reported: the EdgePainter is the first child of the canvas Stack, so a label landing on a card is painted under it and is simply absent -- 8 of 49 figures on one build sent in, 5 of 52 on another. Each slides along its own wire to clear air; along the wire, since a number beside a line belongs to no line. Two things to avoid and they are not equal: under a card it is invisible, over another figure merely crowded, so card-clear wins when nothing clears both (17 crowded pairs left across the corpus). Placement, the label text and its measurement moved out of EdgePainter into labels.dart so the painter, the click test and the anchor cannot disagree. The first measurement of this used a placeholder string instead of the real label and overstated it as 6 of 21; real text is often much shorter |
| E10-69 | ✅ | Nothing is placed on top of anything any more | found by asking how a card gets buried in the first place: of the four ways a card gets a position only add-from-a-port checked. addNode dropped it exactly where you clicked, and paste used a fixed 32 px step -- pasting a build into itself left every card 55 to 64 per cent covered. Paste moves the incoming build as one rectangle, since the arrangement is most of what is being copied. Three copies of nudge-until-clear became one: clearBelow plus cardsOn in overlap.dart |
| E10-68 | ✅ | Tidy no longer leaves cards on top of each other | reported, and confirmed with the new hidden-card check: two overlapping pairs on one build sent in, four on another, all within a column. The priority method places each node in the room its *settled* neighbours leave, and two of its branches -- no wire to flatten, and no room -- keep the node where it was and declare it settled unchecked. Columns are now separated by isotonic regression (pool adjacent violators): subtracting the room each card needs turns the spacing rule into a monotonicity one, whose least-moved solution that is. A plain downward sweep also works and cost 17 per cent more sag against 12, because it can only push down when lifting the card above was cheaper. Corpus sag rebaselined 720102 -> 811177, and the old figure was partly bought by the overlaps. The existing "nothing on top of anything else" test only ever asked one hand-made graph; it asks all 424 now, and catches 132 pairs without the fix |
| E10-67 | ✅ | A card hidden under another card says so | found while measuring the routing, not reported: a build had its Plastic output card lying entirely inside the Glo Squid card, which is why five wires looked like they were drawn through something -- the port one of them wanted was inside the other card. Nothing anywhere said so, and from the outside it reads as a wire bug. Named in the banner with what is on top of it and a button to move it clear; offered rather than done, since two cards on top of each other is sometimes deliberate. Fires only past 60 per cent covered: clipping is untidy, not unusable. The one derived thing a move has to invalidate, so _applyLayout clears it while deliberately keeping everything else |
| E10-67a | ✅ | Move it clear goes past everything, not just the card named | reported with a before and after: the card was moved and landed on another one. Clearing only the card the message names is a fair description of not having been moved clear at all. It now drops below the lowest thing it is touching and looks again, since clearing one card can land it on the next |
| E10-66 | ✅ | Long wires are routed too, and routing got cheaper doing it | reported on a full-screen build: the long wires were the ones still drawn through cards. They had dozens of cards in their bounding box, tripped the give-up cap and fell back to a plain curve -- the wire that most needs routing being the one abandoned. Cards now earn their way into the visibility graph by being shown to block this wire, and the search looks again after each detour, since going round one card can put a wire across another. The candidate lookup had to become a function of where the wire has been pushed to: filtering once against the straight line missed a card the detour flew into. Fewer corners in the graph, so it is faster as well -- 15 ms at 369 nodes against 24, routing more wires |
| E10-65 | ✅ | A wire goes round its own two cards, and a drag only unsettles its own wires | two reports on the first routing. A feedback wire leaves the right edge of one card for the left edge of the other, so it crosses both -- and both were excluded from its obstacles on the reasonable-sounding grounds that a wire may touch what it is attached to. They are obstacles now, with a smaller clearance that must stay under the stub length or the wire would start inside one. Second: dropping all routing for a drag made the whole picture flinch and spring back, when only the wires on the moving card have stopped being true |
| E10-64 | ✅ | Wires go round the cards instead of under them | reported with a picture: an Electrolyzer over a Hydrogen Generator, both wires straight through both cards. The two-stage recipe from Dobkin, Gansner, Koutsofios and North, Implementing a General-Purpose Edge Router (GD 1997): a visibility graph over the card corners with Dijkstra across it, then the polyline rounded off. Two bugs worth remembering -- Liang-Barsky branches on the sign of minus the direction, and Rect.contains is inclusive on the top-left corner, so every card struck out the one corner of itself a wire most wants. Routing is skipped mid-drag: too slow for sixty frames a second, and a stale route leaves the wire off its port |
| E10-63 | ✅ | Dragging a card no longer re-solves the build | every drag frame ran the full elimination: 9.9 ms measured on a reported 41-node build, out of the 16.7 ms a frame has, to re-derive figures that cannot have changed -- nothing under lib/src/solver reads a node x or y. A layout-only path swaps the pipeline and notifies, touching neither the solution nor the caches, which are all keyed on the solution or the wiring. Guarded by object identity: a solve always returns a new instance, so the same one means none happened |
| E10-62 | ✅ | A node drawn harder than it makes says OVER | reported: a refinery making 408 g/s with 2 800 drawn off it showed nothing, while the node it fed lost its NEEDS and looked settled. The marks looked for a leftover and this is the opposite of one. In red and first, being the only one of the four that means something is wrong. On supplies too, which the others are kept off: "you said you have a kilogram a second and this wants four and a half" is worth saying |
| E10-61a | ✅ | Undo takes the note with it, and the note is English | reported: "since the amount blablabla" is not good English, and undoing a delete left "since deleting the ..." on screen. The phrases were written for "this was solving until X" and reused after "since", which does not take a noun -- they are gerunds now and the other sentence puts the edit in the subject. Undo and redo clear the note, which they had never touched |
| E10-61 | ✅ | What your last edit cost | the other half of `E10-55`: that one names the edit that broke a build, this one says what an edit did to the totals when nothing broke, which is the question every message this month has been about. The solution from before the edit is already in hand, so the comparison costs nothing. Only the figures that moved, and nothing at all for an edit that moves none |
| E10-60b | ✅ | A code that will not open says why, where you can see it | reported from a screenshot: the failure sat under a fold about recipes in the same grey as "Share code copied". Three kinds of not-opening are told apart now -- not a code, cut short, damaged -- because the last two look identical to the eye. Found on the way: a code cut by twenty characters decompressed and then failed with "Unterminated string", which is true and addressed to the wrong person |
| E10-60a | ✅ | A box to paste a build into, and a code that says how it is broken | reported: "I cannot use it and I have no error message when clicking the paste build button". The code was damaged -- one character in four hundred and eighty -- and the app had two ways of saying nothing: a clipboard the browser will not read, and a failure that called a damaged code no code at all |
| E10-59 | ✅ | A ceiling means the supply, not each of its lines | found while building `E10-58`: a demo asked what ten kilograms of ore a second could make and was told fifteen kilograms of iron. "At most" was written onto every line leaving the supply, so a supply feeding two things allowed twice. It is a node ceiling now -- one constraint in the optimiser, a warning after the fact in the solver like a valve -- and builds carrying the per-line version still read |
| E10-58 | ✅ | What can I make from what I have | asked twice in a week in different words -- "I know my inputs, not my outputs", and an issue about three Oil Wells and eight Duplicants. Reading every supply amount as a ceiling and then asking an output for the most was already possible, written down in the guide, and never once found there. One button on the output node, one undo, and the answer in the banner because the button goes once its work is done |
| E10-57 | ✅ | A build fits in a message again | every build reported this month arrived as a file attachment, because its code ran to sixteen or twenty-one thousand characters. Gzipped they are three to four, which fits the report link and mostly fits a chat message. The old comment said gzip lived in `dart:io` and would cost the web build -- true of `dart:io`, not of `package:archive`. Old codes are read by the absence of a gzip header, so every one ever sent still opens |
| E10-56 | ✅ | An amount that goes says that it went | reported on issue #2 by somebody who wrote an external tool to force two SET values. Setting an amount on a settled build clears the one that settled it, which is right -- two amounts with no slack between them are a contradiction -- and it happened silently. It is said now. Where the build has slack, both were always kept |
| E10-55 | ✅ | What broke it | every report of a broken build has been phrased "adding X did Y", and the app made people prove what they already knew. The undo stack holds the build that was working, so the banner names the edit that tipped it and offers to undo. Into inconsistency from anything, not merely from solved: a build being drawn is underdetermined half the time and being told off for every node placed is nagging |
| E10-54 | ✅ | A figure with nothing near it | every wrong rate this month was found by a person reading one table against another, never by a test, because every test asked whether a figure was plausible on its own. This one asks whether it is in line with the others of its kind. Honest about its reach: two thirds of figures have no siblings at all, and of the rest a tenfold slip is caught about a sixth of the time. Four was tried and cost seven false alarms |
| E10-53 | ✅ | Why this many | every question about a figure has been a question about which equation settled it, answered by hand each time. The elimination knows -- one row pins each count -- and was throwing away which. Rows carry their identity through the pivoting now, and the answer is a sentence on the node: what you set, what it follows from, or the port whose arithmetic settled it and the two numbers that did |
| E10-51 | ✅ | The button says what it draws | asked for an "add missing outputs" button, which had been there all along inside "Draw N supplies" -- it has always drawn output nodes as well and never said so. Reads "Draw 1 supply and 2 outputs" now |
| E10-52 | ✅ | Two ports at fault, named together | the search for the one over-committed port gave up when there was no one port, and handed over the list. It tries pairs now, up to twenty candidates because every pair is a whole solve between a keystroke and the answer; past that it says outright that no single port is the problem, which is what stops somebody hunting for one |
| E10-50 | ✅ | Things you can click look like it | reported: "lots of clickable that doesn't show they are clickable in the Figures panel". Chips, multipliers, fold headers, pills and the links were bare GestureDetectors -- no cursor on the way over and nothing under the pointer once there. The audit that came with it walks the whole editor and fails on any silent tap target, which found two more in the palette and a search box with no text cursor |
| E10-49 | ✅ | A node says what it is quietly doing | asked for: "mark any blocks that have venting toggled on, spare, or needs-supply details -- realising that was causing imbalance allowed me to diagnose and correct these pipelines". VENT, NEEDS and SPARE on the node header. Not on boundary nodes, where drawing from outside is the whole point, and not for heat, which would have put SPARE on nearly every node in the app |
| E10-48 | ✅ | Wrong? opens a report that already knows the recipe | the button shipped with `E10-35` and the editor passed it nothing, so it was never on screen at all -- tested against a stub for a week. The link carries the recipe and every rate it shows, and a test opens it through the real screen rather than through a callback |
| E10-47 | ✅ | Whatever is left | a third edge mode: this line carries what its port makes less everything else leaving it. An output node on a shared port was either a loose end (consumer-driven, nothing says how much) or a thief (producer-driven, takes the lot); three reports were that one gap. It follows its neighbours, the optimiser answers inside it and leaves it alone, and it says so when there is no rest to send. Costs one thing, said out loud: the producer is no longer sized by what draws from it |
| E10-44 | ✅ | A class port is a compatibility rule, not a choice | reported: the Ethanol Distiller "isn't tolerating combining Gum Wood with Arbor Tree and Oakshell Molt for the Lumber input line, even when set to Any". Any was right; the first wire into a class port settled it. Only the four recipes whose output follows its input -- Metal Refinery, the metal Rock Crusher, both Smooth Hatches -- have anything to settle |
| E10-45 | ✅ | A port promised twice over | reported: "linking Cuddle Pip's dirt back to Arbor Tree zeroes a bunch of stuff". A consumer-driven line with no share brings the port's whole demand, so a producer-driven line into the same port has nowhere to go and the only arithmetic that fits is zero. The mirror of the "already spoken for" error, said as a warning with the same one-click way out |
| E10-43 | ✅ | A line into a fed output joins it, visibly | asked for after the bundling question. Doing it quietly and doing it visibly are not the same: the group is set to the producer and a line above the canvas says what happened and that ⌘Z undoes it. The demo needed the same treatment to stay true, which is how `E10-42` was found |
| E10-41 | ✅ | An output node is a bucket, not a customer | reported as "unsure why the negative draws of resources keep happening", on a build whose four carbon dioxide lines ran into one output. An output has no size of its own, so each consumer-driven line reads its share as a share of whatever the others bring -- which holds every supplier to the same amount. Said whatever the status, because a build with it solves and is wrong, and offered as one click |
| E10-42 | ✅ | The demo was describing the trap as a feature | "Let it choose the split" said the app had split the ore evenly. The ore goes 3.33 and 6.67; what is even is the iron, held there by `E10-41` sitting in the app's own worked example. Found by measuring the demo's flows against its narration, which no test had ever done |
| E10-39 | ✅ | Find a node, with a key | asked for. A build outgrows its window long before it outgrows its author's patience, and the only way to a node forty screens away was remembering where it had been put. Searches the name and the recipe both, because "where does the hydrogen go" is a question about two nodes and only one has the word in its name |
| E10-40 | ✅ | A message says where it means, and takes you there | asked for, and the other half of the report behind `E10-36`: knowing which port is at fault still leaves you hunting the canvas for it. An issue carries the places it names -- ports and wires both -- and each is a button that selects it |
| E10-36 | ✅ | Name the over-committed port, however many there are | reported: "sometimes it lists every single node ... it's hard to tell which one is the problem". The search that names the one guilty port ran a solve per candidate and was capped at 24; the reported build has 26, so it fell back to the wall of names -- and the port it did not look for was the node the author had just added. Budgeted by candidates times nodes instead, and the fallback list stops at six |
| E10-37 | ✅ | A line onto a divided port joins the division | reported: "adding polluted water output to the Petroleum Generator zeroes entire build". A consumer-driven line on a port whose producer-driven lines already take all of it has nothing to take, so the build was refused outright -- for an action that only ever means "send the rest somewhere". The rule now has one implementation that both the check and the app ask |
| E10-38 | ✅ | A share meant as nothing, written as nothing | the simplex answers "nothing goes this way" with 6e-15, and that was written down as a share: it starved three lines out of one port while reading as 0 % on screen |
| E10-35b | ✅ | A counted figure says what it is counting | reported: "what unit / cycle are we talking about?" on a card reading 2 880 000.00 /cycle. Grams say themselves and a count does not — that one is kcal, a plant's growth is percentage points of maturity, and the rest are eggs, gaskets and grooms. An item carries the noun now, and an audit refuses any counted thing a recipe makes without one |
| E10-35a | ✅ | Figures, laid out rather than listed | shown the layout twice and built the feature list twice: a flat list of rows, then cards with no surface, no radius and no colour, which reads as a wireframe of the page rather than the page. Pairs at equal height, a figure set large in the hue of the thing it measures, pills for the other side of the recipe, and the state badge saying the word the reader clicked to get there |
| E10-35 | ✅ | Every figure, where somebody can check it | asked for a way to check the data and report what is wrong with it. Built as a generated Markdown page first, which was a second copy of the data and a page nobody reads — rightly rejected. It is a panel over the live database now, grouped by what comes out and sorted by how much, because that ordering is what makes a ten-times slip visible without knowing either number |
| E10-34 | ✅ | A supply says what you have, or what flows | "I have this much" always meant exactly that much flows, which is what gives a build its scale and is not what anybody means by having something. Both readings are on the node now: an amount, or a ceiling. The ceiling is the valve that already existed, set from where somebody is standing when they say it |
| E10-33 | ✅ | The palette says what a thing is for | the first thing anybody asked and the last still open: "unsure how to make use of Arbor Tree vs Arbor Tree (grazed)". The answer was already written on the spec — the same plant, left for a critter to graze — and the list showed only its name |
| E10-32 | ✅ | What's new | asked for: a small note when a build has changed, and a way to read what changed. Driven by the changelog rather than by the build — a release nobody wrote an entry for has nothing to say, and should not interrupt anybody to say it. The list is the history, so "what changed" and "what has ever changed" are one panel |
| E10-31 | ✅ | Palette groups fold | it is one scroll of about seven hundred rows, and 428 of those are the supply and output node this database generates for every item. The three groups that are one-per-item start folded; searching opens everything |
| E4-62 | ✅ | The Oakshell, and the wood that closes the ethanol loop | reported as missing and it was: it has no page of its own because it is a Pokeshell morph. 70 kg/cycle of polluted dirt, rot pile *or slime*, a quarter of it back as sand, and 100 kg/cycle of molt that a Rock Crusher turns 1:1 into lumber. It is what makes an Arbor Tree loop close — the wiki works that out on the Pokeshell page and nobody would find it there |
| E4-63 | ✅ | A Kelpole is something you can hand to a Kelpole | reported with a build: a Tower Kelp makes kelpoles and *nothing in the app took one*, so the plant could not be sized against the Orehulls it feeds. A kelpole is 10 kg of nori with a five-cycle fuse, which this already said in prose and did not model. The egg it was given went with it — kelpoles hatch from the plant, and that rate was the lifespan wearing an egg's hat |
| E4-64 | ✅ | The Thermal Gas Fissure's gas, and the sulfur that was a quarter of itself | reported from the game with the screenshots to prove it, and the wiki has since filled the page in: 76.9 g/s of natural gas averaged, which this left out on purpose, and 769 g/s of sulfur where this had 192. The 250 kg it recorded is what lands on *one* of the four neutronium tiles |
| E4-65 | ✅ | A Tublia drinks brine as readily as polluted brine | 30 kg/cycle either way, straight off the plant's own panel in a screenshot — the same rate, so it is a choice on the port |
| E4-66 | ✅ | The Polluted Brine Vent | reported missing: 3 kg/s at 95 °C, and the thing that waters the Tublias |
| E4-67 | ✅ | Sublimation, where the gas costs something | requested: a node for offgassing that actually eats the thing that offgasses, instead of conjuring polluted oxygen out of a supply node. Four of them. Only slime has a rate that does not depend on how big the pile is — the rest go as a power of the mass, so they are quoted per 1000 kg pile and say so in their names. Polluted dirt is left out: the plausible-rates audit refused two thirds of a gram a second from a tonne, and it was right, which is why the game gives you a Sublimation Station instead |
| E4-68 | ✅ | The Orehull's iron ore was ten times itself | reported: 250 kg a cycle where the game gives 250 kg every *ten*. The figure is on the Iron Ore page rather than the Orehull's, which is why this shipped as a guess and said so |
| E4-69 | ✅ | The Cuddle Pip | reported: a Pip that eats Arbor Tree turns into one, so a build with grazed Arbor Trees grows them whether you meant to or not. Wants the morph's own diet, yields and egg rate |
| E4-70 | ✅ | A grazed Arbor Tree has five branches | it offered a tenth of what it grows, because it was read as one plant maturing over nine cycles instead of five branches regrowing over four and a half. Three figures say 12.5 Pips to a domestic tree — 0.08 trees per Pip, 0.32 wild ones, and the Arbor Tree's own "feeds 12.3 adult Pips" — and this said 1.25. Found while adding `E4-69` |
| E4-71 | ✅ | A Pip makes twenty kilograms of dirt a cycle | it made ten. The Pip's own table says 20 kg, and the same page says one Pip supplies two Mealwood or two domestic Arbor Trees or four Sleet Wheat — every one of which is 20 kg a cycle of dirt |
| E4-72 | ✅ | A power network is one thing, not a wire to each consumer | the first issue anybody opened, and a good one: in the game a grid is a shared bus, so two generators and three consumers should be generation minus consumption, not six wires and a 33/33/33 guess. A node for the bus itself, which is a thing you can see rather than a rule the solver applies behind you |
| E4-73 | ✅ | A Drecko excretes phosphorite | the thing it is kept for, and it had none: "a renewable source of Phosphorite" is the first line of its page, and the rate is on the Phosphorite page — 10 kg/cycle, 9 for a Glossy. Found in a specification somebody pasted in for something else entirely, which is the third time this week the fix came from a person reading rather than a test |
| E4-57 | P3 | The last kitchen ingredients nothing grows | grubfruit needs a Divergent to tend the plant, sweatcorn a pollinator, jawbo fillet and calamari their critters, and bog jelly, ovagro fig, plume squash and tonic root their own plants. Each is blocked on a figure or a creature, not on effort |
| E4-44 | ✅ | Plywood, and the press that makes it | the fifth thing the Kiln burns. 90 kg of plant husk and 10 kg of resin make 100 kg in 40 s of Duplicant time, and both ingredients were already here — resin came off the unused-on-purpose list, which is what that list is for |
| E4-42 | ✅ | Biodiesel, the third fuel | the material and the generator's third choice. What *makes* it is still out: the Emulsifier has no published cycle time — the same wall Super Coolant hit in `E13-9a` — and the Husky Moo is not modelled |
| E4-11 | P2 | Confirm the unverified DLC rates once the wiki fills them in | checked again 2026-08-22: the Vulcanizer's latex and rubber rates, the Plant Pulverizer's cycle time and the Gum Palm's carbon dioxide are all still absent — the Marine Drill's natural gas has since been published and is `E4-64`. Everything else on those four pages has been read across |
| E4-11a | ✅ | The Marine Drill's sulfur | 250 kg an operation over a 1 300 s cycle is 192 g/s, and a thousandth of that had been sitting in a field measured in grams since the day it was seeded |
| E4-12 | ✅ | Palette filter by DLC |
| E4-13 | ✅ | User-defined / overridable processes, edited in the app |
| E4-17 | ✅ | Share a custom recipe pack, so a wiki gap gets filled once for everyone | one code for everything you have written, items included, merged on paste with the replacements counted out loud |
| E4-10 | ✅ | Data version stamp | `dataVersion` + game build in the JSON so saved pipelines can warn on mismatch |
| E4-9b | ✅ | The Aquatic critter roster | Beakon, Slogo, Gildgo, Orehull, Glo Squid, Seaquine, Kelpole — individual pages carry rates the summary table omits |
| E4-12a | ✅ | The port menu obeys the palette filters | and learned about material classes while there |
| E4-12b | ✅ | The recipe editor's item picker obeys them too | checking whether item pack tags could be trusted found three that were wrong |
| E4-14 | ✅ | Geyser activity | `outputScale` scales what a node produces without touching what it consumes; worst/typical/best presets |
| E4-14a | ✅ | Geysers, vents and volcanoes | 19 natural sources with wiki average rates and output temperatures |
| E4-15 | ✅ | Six more base-game critters | Pip, Pokeshell, Gassy Moo, Plug Slug, Shove Vole, Shine Bug |
| E4-16 | ✅ | Ranching costs and yields | eggs per groomed interval, meat over a lifespan, 12 s of Duplicant time a cycle each |
| E4-18 | ✅ | Measured geyser figures | type the exact active percentage Field Research reports, not just a preset band |
| E4-19 | ✅ | Ranching buildings | Grooming, Aquatic Grooming and Shearing Stations, sized by a capacity link rather than a pin |
| E4-20 | ✅ | Egg mass and shells | the Egg Cracker and the shell-to-lime crusher, so a ranch's eggs are food and lime rather than a number nothing consumes |
| E4-20b | P3 | Eggs per critter | a Bammoth's egg is four times a Hatch's, and this app has one Egg item; the cracker uses Hatch figures |
| E4-21 | ✅ | Wild versus groomed | a `(wild)` twin per ranched critter: no grooming, no Duplicant time, a tenth of the eggs |
| E4-21b | P3 | Glo Squid and Seaquine wild twins | wants somebody to check in game which outputs the milking station takes |
| E4-22 | ✅ | The Grooming Station's power draw | none. The wiki never said, in years of asking; a player read it out of the game files. It is what this modelled on the guess that silence meant none, so nothing changed but the certainty. Capacity is still open as `E4-48` |
| E4-23 | ✅ | Sweetle and Grubgrub | seeded once `E13-8` made Spaced Out a pack you can switch off. The Beeta is `E4-23a`: a five-cycle life would be misrepresented by a per-cycle average |
| E4-23a | P3 | The Beeta | it lives five cycles and its honey comes at the end of them, so a rate is the wrong shape for it — the same reason the app refuses to average a Bammoth's shearing |
| E4-24 | ✅ | The Frosty and Prehistoric Planet Packs | 21 elements, Peat Burner, Ice Liquefier, Wood Heater, Alveo Vera, five critters |
| E4-25 | P3 | Firm up the inferred 50 % conversions | two of the three answered: the Pokeshell's 50 % is published, and the Shine Bug's feed is 200 g of phosphorite a cycle — the one food of its several the page weighs rather than counts in calories. The Pip's is not: its page says what it eats and what it excretes and never puts the two in one sentence |
| E4-25a | ✅ | The Shine Bug's feed | 200 g of phosphorite a cycle, which its page weighs while counting its other foods in calories |
| E4-26 | P3 | The rest of both packs | the Bammoth is done (`E4-26a`). Jawbo's yields are unpublished, Rhex eats other critters and a flow model cannot express that, Gnit and Mimika produce nothing, and the regular Lumb's peat rate is stated nowhere |
| E4-26a | ✅ | The Bammoth | 30 kg/cycle of Plume Squash or Nosh Bean, all of it back as patty, and a Rock Crusher recipe that splits 120 kg of patty into 88 of clay and 32 of phosphorite |
| E4-27 | ✅ | Mercury and cinnabar processing | the generic refinery and crusher already covered the rates — 1:1 and 50 % with sand — but the ore refined to the wrong element: a refinery hands its metal back at 40 °C and mercury freezes at −38.85 °C, so what you get is a liquid |
| E4-28 | P3 | Seaquine's ovolene rate | checked again 2026-08-22: the page says who may be milked and never how much. Its diet and its carbon dioxide are published and are already here |
| E4-29 | ✅ | The remaining grazers, properly | Drecko, Glossy Drecko, Pip and Flox switched from kilogram stand-ins to real growth links |
| E4-30 | ✅ | Plant growth as a capacity link | a grazing critter eats a fraction of a living plant, not kilograms off a pile |
| E4-31 | ✅ | Wild plants | a wild twin per crop: no water, no fertiliser, a quarter of the speed |
| E4-32 | ✅ | Thimble Reed as the Pip's other crop | one recipe with two crops, since 8.89 % of maturity a cycle is a fact about the Pip and not about what it is eating. The Bammoth half belongs to `E4-26`, whose yields are unpublished |
| E4-33 | ✅ | The food chain | Bristle Blossom, Dusk Cap, Waterweed, Sleet Wheat and the Electric Grill |
| E4-34 | ✅ | Cooking | Gas Range, Deep Fryer and Sushi Bar, gas burned and Duplicant time included |
| E4-34b | ✅ | The Microbe Musher and Smoker | both seeded; food *quality* remains unmodelled, which is E4-38 |
| E4-38 | ❌ | Food quality | decided against, for the reason germs were: it changes no rate. A Duplicant eats the same kilocalories of a bad meal as a good one — what quality buys is morale, which is a person and not a flow |
| E4-35 | ✅ | Three more crops | Pincha Pepperplant, Thimble Reed, Nosh Sprout, each with a grazed twin |
| E4-35b | ✅ | Sporechid, and the Prehistoric and Aquatic food plants | checked 2026-08-23 and closed by finding out what each one is: the Sporechid produces nothing a pipeline carries, and the Prehistoric food plants want a pollinator, which is not a flow. What is left is `E4-35c` |
| E4-35c | P3 | The plants that want a pollinator | Sweatcorn and its neighbours need a Mimika or a Divergent to set fruit, and how often that happens is a fact about your base's critters rather than about the plant. Their water is unpublished too |
| E4-36 | ✅ | Harvested and grazed are separate processes | offering both on one process let a farm be counted twice |
| E4-37 | ✅ | The rest of the Aquatic plants | Sodicane and Clampum seeded; the other five are not plants a pipeline has anything to say about, which is written out below |
| E4-37b | P3 | Pinpoket | its yield is quoted as processed diamond per cycle rather than as a harvest, and "0.25 cycles per unit" contradicts its 16-cycle growth. Wants somebody with the game open |

## E5 — Persistence & interop

| id | P | Task |
|---|---|---|
| E5-1 | ✅ | `Pipeline` ⇄ JSON (`toJson`/`fromJson`) with a schema version + migrations hook |
| E5-1a | ✅ | A build from a newer app is refused | it used to be read as though it were this format, and written back still claiming the newer one |
| E5-1b | ✅ | Copying a build copies all of it | importing and duplicating rebuilt it field by field and had already forgotten one |
| E5-2 | ✅ | Local save/load of user pipelines (`path_provider` + file, or `hive`/`isar` — decide in a spike) |
| E5-3 | ✅ | Share a pipeline as a base64 code |
| E5-4 | ✅ | Import/export to clipboard |
| E5-2a | ✅ | Persistence groundwork |
| E5-6 | ✅ | Corrected recipes are named |
| E5-6a | ✅ | Correcting a recipe stopped erasing what it is built from | `editable` dropped the build cost and the overheat rating, and the form had no field for either. Both carried through now, and the cost has a line per material |
| E5-6b | ✅ | A material you invent is a material you have | a custom item got no supply or output node, so nothing could feed the recipe that asked for it |
| E5-6c | ✅ | An invented material says what kind it is | everything invented was silently a solid, which decides its pipe, its pump and whether it has a temperature at all |
| E5-6d | ✅ | An invented material can be got rid of | it lives as long as a recipe of yours uses it, and one typo used to leave five palette entries for ever |
| E5-7 | ✅ | Export to a file | to the downloads folder, with the path said out loud, and no picker dependency. Reading one back still wants a picker, and the clipboard covers it meanwhile |
| E5-8 | ✅ | Copy the build as text | the plain-text summary, for a forum post or a note rather than another copy of this app |
| E5-9 | ✅ | Somewhere for a browser to keep things | `localStorage`, behind the same `JsonStore` the file store is behind. Checked in a real Chrome rather than assumed: `flutter test --platform chrome` |
| E5-8a | ✅ | Which platforms this really runs on | macOS is built and smoke-tested; web compiles and would forget everything, so it says so and takes a memory store rather than a file store that throws |

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
| E6-1 | ✅ | forui wired up, Material dropped | no `package:flutter/material.dart` anywhere in `app/lib` |
| E6-2 | ✅ | State management | `PipelineController extends ChangeNotifier`: holds the `Pipeline`, the current `PipelineSolution`, selection, and an undo stack. No riverpod — the engine is pure and the app has one document |
| E6-3 | ✅ | Re-solve on every edit | any mutation re-runs the solver and repaints; target < 16 ms for a 100-node graph |
| E6-4 | ✅ | Undo/redo | trivial: `Pipeline` is immutable, so the stack is a `List<Pipeline>` |
| E6-5 | ✅ | Desktop-first window chrome, keyboard shortcuts (⌘Z, ⌫, ⌘F) |
| E6-6 | ✅ | Multi-document: open several pipelines in tabs |

## E9 — Design system (`lib/design/`)

| id | P | Task | Notes |
|---|---|---|---|
| E9-1 | ✅ | Tokens | `OniColors`, `OniSpacing`, `OniTypography`; colour is *data*, not decoration. Two palettes since E9-6, read through `OniTheme.current` |
| E9-2 | ✅ | Item-category palette | solid / liquid / gas / power / heat each get a hue, used identically on ports, edges and legends — the single most important visual rule in the app |
| E9-3 | ✅ | Wrappers | `OniPanel`, `OniButton`, `OniField`, `OniSelect`, `OniTooltip` over forui equivalents |
| E9-4 | ✅ | Numeric formatting widget | reuses the engine's `Unit.format`; per-second ⇄ per-cycle toggle in one place |
| E9-5 | ✅ | Icon set | a drawn glyph per item category — drop, ring, square, bolt, diamond, pill, cross — so shape carries what colour alone was carrying |
| E9-6 | ✅ | Light theme | `OniPalette.dark` / `.light` behind `OniTheme.current`; ☀/☾ on the toolbar, remembered. Not an inversion — each colour picked for its own background; tests hold every pair apart and hold text ≥7:1 against the page |
| E9-7 | ✅ | A cross to empty a search | on every search field, since getting back to the whole list should not mean holding backspace |
| E9-8 | ✅ | Searching the palette by material | "what makes oxygen?" is the first question anybody asks a production planner, and the list matched names only |
| E9-9 | ✅ | The empty canvas offers the worked builds | it said what to do and gave nothing to press, while four examples sat two clicks away in a menu |
| E9-10 | ✅ | The keys are written down | nineteen bindings, three of them documented; copy and paste of nodes was written down nowhere, and the guide is checked against the map now |
| E9-11 | ✅ | Change the recipe on a node | a building with several recipes can be swapped in place, keeping its position and the wires that still fit |
| E9-12 | ✅ | A card of the keys | a button that pins it open, and ? that shows it only while held |
| E9-12a | ✅ | Holding the key makes no noise | macOS beeps at every key event nothing claims, and a held key repeats a dozen times a second |

## E7 — The canvas

The part no library gives us: `widgets.dart` + `CustomPainter` + raw gestures.

| id | P | Task | Notes |
|---|---|---|---|
| E7-1 | ✅ | Viewport | `Matrix4` pan/zoom driven by `Listener` + `GestureDetector`; explicit screen ⇄ world coordinate conversion, because every hit test needs it. Trackpad pinch and scroll-to-pan |
| E7-2 | ✅ | Node widget | real widgets inside a `Stack` (not painted), so text, focus and hit-testing come free. Shows name, solved count, `build N`, a utilisation bar, and its ports as dots |
| E7-3 | ✅ | Edge painter | one `CustomPaint` *under* the nodes: bezier per edge, colour by item category, **thickness ∝ flow**, flow label at the midpoint |
| E7-4 | ✅ | Selection | click a node or an edge; selection drives the inspector |
| E7-5 | ✅ | Drag a node | updates `PipelineNode.x/y`, snaps to a grid |
| E7-6 | ✅ | Drag-from-port to connect | live bezier following the cursor; compatible target ports light up, incompatible ones dim; drop on empty space opens the palette filtered to processes that accept that item |
| E7-7 | ✅ | Delete | node or edge, with the edges of a deleted node going too |
| E7-8 | ✅ | Empty state | a real "add your first node" affordance, not a blank void |
| E7-9 | ✅ | Auto-layout (layered / Sugiyama) |
| E7-10 | ✅ | Marquee select, group move |
| E7-11 | ✅ | Minimap |
| E7-12 | ✅ | Tidy a selection |
| E7-13 | ✅ | Space-drag-to-pan, and a plain drag selects | decided by Hugo on 2026-08-22, having been held back because it changes a gesture in use. Three ways to pan — space, middle button, two fingers — so nothing is taken away without a replacement |
| E7-14 | ✅ | Fit a selection |
| E7-15 | ✅ | The view glides |
| E7-16 | ✅ | The view follows a drag off the edge |
| E7-17 | ✅ | Port-aware ordering | the barycentre and the crossing count both use where a wire attaches, not the middle of the node |
| E7-18 | ✅ | Coordinate assignment | the priority method: the heaviest wire decides where a node sits, scored so straightening never costs a crossing |
| E7-19 | ✅ | Lanes kept through placement | a wire passing a column keeps its room, and the layout scores crossings, then wires over nodes, then droop |
| E7-20 | ✅ | Arrow keys nudge the selection | one grid cell, eight with shift; a run of presses collapses into one undo |

## E10 — Panels & the pin interaction

| id | P | Task | Notes |
|---|---|---|---|
| E10-1 | ✅ | Process palette | searchable, grouped by tag (oxygen / power / liquid / refining), click or drag to place. Sources and sinks listed per item |
| E10-2 | ✅ | **Pin control** — the headline | select a node → "I have ▢ of these" (buildings) or "▢ g/s" (source/sink). Pinned node wears a lock badge; clearing it is one click |
| E10-3 | ✅ | Inspector | selected node: every port with its solved rate, what is connected, power, heat, uptime, and the `unverified` warning if the data ever carries one |
| E10-4 | ✅ | Summary bar | net power, total heat, raw inputs, net outputs, dupe labour — always visible |
| E10-5 | ✅ | Problems panel | solver issues as a real list: underdetermined (with the "pin one of these" nodes as buttons), inconsistent, shortages |
| E10-6 | ✅ | Edge inspector | pull ⇄ push toggle and the share slider, explained in words rather than jargon |
| E10-7 | ✅ | Per-cycle ⇄ per-second toggle |
| E10-8 | ✅ | Templates | SPOM, petroleum boiler, Hatch ranch and cooling loop, laid out on the way in; the first-run build is one of them |
| E10-9 | ✅ | The numbers on the wires are clickable |
| E10-10 | ✅ | Totals scoped to one build | two builds on a canvas were summed together, which described neither; the selection decides which one the bar is about |
| E10-11 | ✅ | Toolbar grouping | history, arrangement and units separated by a rule, rather than one evenly spaced row |
| E10-12 | ✅ | The summary bar fits any window | single-line labels and a bar that scrolls sideways; tested at five widths, with the panels and the menu at three |
| E10-13 | ✅ | Saving a build as a node, explained | its own section in the menu, saying what it will do and where the result goes |
| E10-14 | ✅ | The pipelines menu reads as sections | pressable headers with a turning chevron, a heading over the saved builds, and a rule between each |
| E10-15 | ✅ | Draw the supplies | a supply or output node for every unfed port, in one press and one undo; the button appears only while there is something to draw |
| E10-16 | ✅ | Part-time buildings | an uptime control, distinct from the "busy" figure: one is a choice you make, the other is what rounding leaves you |
| E10-20 | ✅ | What your geyser actually gives | the activity control covered how often it is awake and not how much it emits, which is the other number the world rolls |
| E10-21 | ✅ | The arrows move the caret while you type | every other canvas shortcut stood down for a text field and the nudge did not |
| E10-22 | ✅ | The flow label sits in the middle of its wire | it was a third along, which reads as belonging to one end |
| E10-23 | ✅ | The build that cannot balance says which port to fix | it named every port that pulls, and most of them were innocent |
| E10-24 | ✅ | Picking a class-port building from the port menu works | the menu offered on one rule and the click accepted on a stricter one |
| E10-25 | ✅ | An ore refines into its own metal, not any metal | the wires settle a class port, and four recipes tie an output to an input |
| E10-26 | ✅ | "Use as little as possible" no longer empties the build | the cheapest way to use no ore is to make no metal, and it applied that |
| E10-27 | ✅ | The app is published on every green push | GitHub Pages, gated on the tests |
| E10-28 | ✅ | The toolbar's actions end at the right edge | a loose flexible child left its unused share as a gap after them |
| E10-28a | ✅ | The status text stops holding room it has no words for | the same flex mistake, one step on: a share of the bar rather than a gap at its end |
| E10-29 | ✅ | The shortcuts work on a keyboard without a ⌘ key | every binding said meta, so Windows and Linux had no undo at all |
| E10-17 | ✅ | An edge's share | settable on a push line, with "an even split" as a real answer rather than a silent default |
| E10-18 | ✅ | The stockpile pin | "I have 2 t of coal and want it to last 20 cycles"; the third pin kind, modelled since the solver was written and unreachable until now |
| E10-19 | ❌ | Clearing every amount at once | decided against. `clearAllPins` looked unreachable because the sweep only read `lib/`; four tests use it to build an unpinned graph, which is a fair reason for a method to exist. Nobody needs a button for it |

## E11 — What a build actually costs to run

Started when the model could balance matter perfectly and still describe something
unbuildable. Everything here is a thing the game charges you for that a flow graph
does not see.

| id | P | Task | Notes |
|---|---|---|---|
| E11-1 | ✅ | Conduit capacity | how many pipes, wires and rails a flow needs; a ratio that balances on paper is unbuildable at 40 kg/s down one pipe |
| E11-2 | ✅ | Pipe materials | a hot wire names the coolest material that holds it and the range above |
| E11-3 | ✅ | Pumps | generated per fluid the way sources and sinks are, since a pump is the same machine whatever it moves |
| E11-4 | ✅ | Filters | generated per fluid; what a separation *costs*, since the separation itself needs mixtures the model does not have |
| E11-8 | ❌ | Mixtures | decided against for now in `docs/MIXTURES.md`, with the conditions that would change it. Of the three things it was wanted for, two are about layout and the third — two gases sharing a pipe — was built, measured against every template, and found to occur on none of them |
| E11-9 | ✅ | Valves | the blocker dissolved when `E3-7a` landed a simplex: the solver still cannot hold a cap and now says when the build breaks one, and the optimiser holds it natively so "as much as possible" answers with your valves shut |
| E11-5 | ✅ | Conduit heat | how much heat a line carries against a 25 °C base, which is the cooling it would cost. Where that heat lands needs the pipe's material and what it runs past — geometry this model does not have — so the size is said and the destination is not |
| E11-6 | ✅ | Temperature mixing | carried downstream after the solve; published figures win, the rest is the weighted mixture of what arrives |
| E11-6b | ✅ | The specific heats not yet measured | all thirty fluids have one now, so no mixture drops a term and every coolant has an Aquatuner |
| E11-7 | ✅ | Construction materials | what it takes to put a building up, counted per building placed and totalled as a shopping list |
| E11-7b | ✅ | What a Gasket costs | 50 kg makes one, in 30 s at the Crafting Station. A counted part now says what one costs beside it, worked out from whatever recipe makes it rather than written down twice |
| E11-2b | ✅ | What to build *this* out of | the wire's advice names the whole table, and a building cannot use the whole table: it narrows to the class the build cost asks for, and says plainly when nothing in that class holds. Buildings the game rates itself (Steam Turbine, 1 000 °C) are not asked |
| E11-7c | ✅ | Build costs in their own unit | gaskets are counted, everything else weighed; the headline total sums only what has a weight |

## E12 — What using it turned up

Not planned. Every row here is something that only showed up once the app was being used
to build something real, which is a different activity from writing it.

| id | P | Task | Notes |
|---|---|---|---|
| E12-1 | ✅ | Saved builds survive the data changing | splitting the plants removed ports that saved builds were wired by; repair moves a node to the sibling that still has them |
| E12-2 | ✅ | Zoom that can be found | a trackpad pinch did nothing at all, and the only other way in was a keyboard shortcut nobody had been told about |
| E12-3 | ✅ | Nodes away from the origin can be clicked | the node layer was laid out at viewport size, so anything outside it was painted and dead |
| E12-4 | ✅ | A dragged card follows the pointer | three faults compounding: a doubled zoom correction, per-frame snapping discarding remainders, and the drag slop being lost |
| E12-5 | ✅ | The scale warning speaks English | it said "Not enough pins: spare could be anything", which is three pieces of jargon in six words |
| E12-6 | ✅ | Selecting a node goes to it | being told which node is the problem is no use when it is off screen |
| E12-7 | ✅ | Two builds on one canvas | an amount belongs to the build it was given to, not to the page |
| E12-9 | ✅ | The port menu's empty list tells the truth | there is no dead end to build a door out of: every one of 1 415 ports has something to offer, so "nothing here makes water" was only ever shown to somebody whose *search* found nothing, and it blamed the catalogue for that |
| E12-8 | ✅ | ⌘C / ⌘V for nodes | copy a selection into the same canvas or another build |
| E12-24 | ✅ | The release that adds the notice can announce itself | deployed and nobody was told, because on a first run the newest entry is recorded silently — and on the day the feature ships, every reader is on their first run. Somebody with saved builds has been here before, and that is the signal it now uses |
| E12-23 | ✅ | "I know my inputs, not my outputs" is answerable | said four ways and each time it was right. Put a valve on each supply — which is what having something means, at most — and ask an output for as much as possible: the optimiser had the answer all along and threw the scale away, writing shares and no amount, so the build came back as undecided as it started |
| E12-22 | ✅ | A build with two loose ends can be given two amounts | the root of a long thread: setting an amount cleared every other amount in the same connected build, because "one amount per build" assumed a build has one loose end. Where it has two, the app told somebody to give two and then made it impossible |
| E12-21 | ✅ | "I have this much" on a supply means exactly that much flows | asked three times how to solve a build from known inputs, and the honest answer was that giving every supply its amount breaks it: a supply with more than the build needs is a contradiction, not a spare. The field says *have*; the pin says *flows*. It says so now when it bites, and names the amount actually used |
| E12-20 | ✅ | "One of" was two of | a build with two loose ends said "give an amount for one of: Sand output, Water output", and giving one left it exactly as stuck, naming the other. The count of loose ends is how many amounts it needs, and it was reading as a menu to pick from |
| E12-19 | ✅ | A wire's share counts the wires that are actually there | "taking everything the port makes, since nothing else is asking for it", said with two other wires asking for it. It counted only the producer-driven ones, so consumer-driven wires off the same port were invisible to the sentence and to the choice of label above it |
| E12-18 | ✅ | A port already divided has nothing left for another wire | reported from a sixty-node build: seven nodes solved to negative amounts and the only advice was "check the edge shares". One port explained all of it — a generator whose power was already shared out 100 % among six wires, with three more added afterwards. It says which port, and how much is left |
| E12-17 | ✅ | An answer the optimiser gives is a build that solves | reported as "basic build is now broken": a plain SPOM that would not balance at any size, because a share of 0 had been written onto its spare-power outlet. Zero is a deletion rather than a division. Underneath it, the optimiser lets an output port keep a surplus and the solver does not, so an answer could be one the app then called impossible |
| E12-16 | ✅ | A share of 1.0000000000000009 is a share of one | reported with a build the app had itself written: the optimiser divides a flow by a production and the answer lands a hair outside [0, 1], which the per-edge check rejected while the check on their *sum* three lines below already tolerated a rounding. Every wire went to zero and the only way out was to draw it again |
| E12-15 | ✅ | Asking twice gives the same answer | reported: "use as little as possible works once, but if you keep pressing it, it will go the other direction". It walked a build from 90 g/s of bought water to 191, 304, 430. The optimiser read every share against the producer while the solver reads a pull share against the consumer, so the answers it wrote came back through it meaning something else |
| E12-14 | ✅ | 4.00 of something is four of it, not five | reported: "Ethanol Distiller will say 4.00× Build 5, 80%". A count a millionth above a whole number was rounded up to the next building, and the number printed beside it had already rounded down. Every rate in this data has six digits at best, so a whole number to within a millionth is a whole number |
| E12-13 | ✅ | A vented port can be over-drawn without saying so | found while checking a reported build: venting removed the port's balance equation altogether, so three wires could draw 4.83 kg/s of sulfur out of a drill making 4.62 and the build still read `solved`, 4.6 % optimistic in every count downstream. Venting means the surplus may go to waste, not that the shortfall may be conjured |
| E12-11 | ✅ | Two wires into one port say what they are doing | reported twice from one build: a Petroleum Generator's own polluted water plus a supply to top it up came out as *twice* the trees, because two wires into one input split its demand evenly and nothing said so. Setting both to "the producer" has always solved it exactly — 750 g/s from the generator and 90 topped up — and nothing pointed there |
| E12-12 | ✅ | The over-committed list stops repeating itself | eight bullets of the same forty words, one per port, with the one that mattered indistinguishable from four innocent ones. The function's own comment already said listing them all "was no help" |
| E12-10 | ✅ | A wire follows its port when the port is renamed | today's food work renamed six port ids, and a port id is part of the saved format: every build wired to `sleet_wheat_grain` lost that wire. Repair now moves a wire to the port carrying the same thing, and drops it only when the guess would be a guess |

## E13 — Materials as classes

Started when the palette was heading for one Metal Refinery per ore. A port can ask for a
class of material and take any member; it is a compatibility rule rather than a new kind of
flow, so the solver never had to learn about it.

| id | P | Task | Notes |
|---|---|---|---|
| E13-1 | ✅ | Material classes | Metal Ore, Refined Metal, Raw Mineral, Compostable, Filtration Medium, Cultivable Soil, Wood; validated on load, no class of classes |
| E13-1b | ✅ | Naming the metal | a node says which member it uses, and an output that follows an input takes it from there: copper ore in, copper out |
| E13-1c | ✅ | Classes applied where verified | Deodorizer and Water Sieve on Filtration Medium, a Hatch on rock, a Smooth Hatch on any ore, the Ethanol Distiller on wood |
| E13-2 | ✅ | The cooling loop | Aquatuner and Thermo Regulator move heat, the Steam Turbine deletes it; heat ports at both ends so a build must say where it went |
| E13-2b | ✅ | The rest of the roster | the Smoker and the Dehydrator seeded; the other three cannot be, each for its own reason, written out below |
| E13-2c | P3 | The Molecular Forge | checked again 2026-08-23: the five recipes' *ratios* are published — thermium is 5 kg of niobium and 95 of tungsten, and so on — and the cycle time still is not, nor the power per recipe. It also wants ten items nothing else here uses |
| E13-2d | P3 | The Spice Grinder | every recipe is 0.1 of a *seed*, and seeds are not items here; no power or cycle time published either |
| E13-2e | ❌ | The Supermaterial Refinery | it is the Molecular Forge under an older name. The page 404s, and the Forge makes exactly its recipes — thermium, insulite, plastium. `E13-2c` is the row |
| E13-3 | ✅ | The Crafting Station | the gasket recipe seeded — 50 kg of plastic or rubber, one gasket, 30 s, 60 W. Its other recipes make equipment rather than materials: oxygen masks, power banks and boosters, none of which is a flow |
| E13-4 | ✅ | Lead, and the metals behind galena | galena is the one ore that is two things — 87 % lead, 13 % sulfur — so it has its own refinery and crusher recipes and the generic ones exclude it, which is what `excludes` on a port is for |
| E13-5 | ✅ | Sage Hatch's organics | six foods at one rate, so it is a port with alternatives rather than an invented "organic" class. Prepared food is 700 kcal a cycle rather than a weight, which is a different recipe and stays unmodelled |
| E13-6 | ✅ | Alternative diets | a Plug Slug eats ore or refined metal at the same 60 kg a cycle, so it is one port with alternatives rather than two specs |
| E13-7 | ✅ | Rot Pile | the Pokeshell's second food and the Compost's third input; what makes it is food spoiling, which this app does not model, so it arrives as a supply |
| E13-8 | ✅ | Spaced Out as a fourth pack | the audit it was waiting on found the surface to be tiny: liquid sulfur, sucrose, the Plug Slug and the sulfur geyser, because nothing here models rockets or radiation. Offered like the other three |
| E13-8a | ✅ | The pack tags, read against the packs' own lists | five wrong: Ice and Abyssalite are base game, Sucrose is Spaced Out, and Amber and Resin are named on the Prehistoric pack's own list while carrying the Aquatic tag |
| E13-9 | ✅ | Aquatuner and Thermo Regulator for every coolant | generated per fluid from its specific heat, the way pumps and filters are, since a class would be wrong — every member behaves differently |
| E13-9a | ✅ | Super Coolant | 8.44 DTU/g°C, so one Aquatuner of it moves more heat than a Steam Turbine can take away. The Emulsifier that makes it has no published cycle time, so the material is here and the recipe is not |
| E13-10 | ✅ | The Smoker's fuel | one recipe per fuel, the Beakon pattern. A class is for a category the *game* groups; "either of these two" is not one |
| E13-11 | ✅ | A port that names its alternatives | a port lists what it will take and the node picks, the way a refinery picks its ore. Only where the rate is the same for each; different rates are different recipes |

## E14 — Being told when it is wrong

The app is public now, and the only bugs that get fixed are the ones somebody can report.
The thing that makes a report about *this* app useful is the build that caused it, and a
build is already one code — so the report should arrive carrying it.

| id | P | Task | Notes |
|---|---|---|---|
| E14-1 | ✅ | The app says which build it is | the commit, passed in at build time and shown where a report can quote it. "Which version?" is otherwise the first question every time |
| E14-2 | ✅ | An issue form for a bug and one for an idea | `.github/ISSUE_TEMPLATE`, so what is needed is asked for rather than hoped for — including the share code of the build it happened on |
| E14-3 | ✅ | Report it, from inside the app | a link in the guide's footer that opens the form with the version, the platform and the size of the build already filled in, and the share code when it fits in a URL |

## E15 — The app demonstrating itself

`docs/DEMO.md` is ten minutes of somebody who knows the app driving it in front of somebody
who does not. Most people who open the site will have neither person in the room. This is that
script, played by the app.

The rule that makes it worth building rather than a video: **a demo drives the real
controller.** Every step is a thing you could have done — place this, wire that, pin the
geyser to one — and every number on screen comes out of the solver as usual. A demo that
paints its own figures would be a lie the first time a recipe changed, and this app's whole
argument is that its numbers are checkable.

On `E15-8`, what "first visit" can honestly mean: this app knows only what is in the browser's
own storage, so a cleared browser, a private window and a second machine each look like a
first visit and will each be offered it again. That is the right failure — an offer shown
twice costs a click, and one never shown costs the visit. Two things it must not do: interrupt
somebody who arrived on a shared build, since they came to see *that*, and come back once it
has been dismissed.

| id | P | Task | Notes |
|---|---|---|---|
| E15-1 | ✅ | The demo engine | a demo is a list of steps; a step is an action on a real `PipelineController` plus a line of narration. No animation framework, no second renderer, and nothing a person could not have typed |
| E15-2 | ✅ | The player | play, pause, step forward, and leave at any point. It runs in a workspace tab of its own, so whatever you were building is exactly where you left it — a demo that eats your work is worse than no demo |
| E15-3 | ✅ | The narration is checked against the solver | the test that stops it rotting: run every demo to its end and compare each figure a caption states with what the app actually says. A caption that quotes 16 Duplicants fails the day the Electrolyzer's rate is corrected. Same idea as the guide-and-asset check, for the same reason |
| E15-4 | ✅ | "What a geyser feeds" | act one: geyser → Electrolyzer → Duplicants, the red −216 W, then the Hydrogen Generator that turns it green. The SPOM discovered in two clicks rather than looked up |
| E15-5 | ✅ | "Let it choose the split" | act two: one ore, a refinery and a crusher, an even split at 6.67 kg/s, and 10.00 kg/s once it is asked for the best. The part no other ONI calculator does |
| E15-6 | ✅ | Where it is offered | the empty canvas already offers four builds to start from; a demo belongs beside them, and in the guide. Always reachable, never in the way |
| E15-8 | ✅ | Offered once, on a first visit | the one moment somebody does not know there is anything to see. An *offer* — a line on the empty canvas with a button — never a thing that starts playing at somebody. Taken or dismissed, it does not come back |
| E15-9 | ✅ | The canvas keeps up with the demo | a demo places nodes off to the right and the finished one is 1 152 px wide, which is more than the canvas has. The player fits the view after each step — E15-2 said this was its job and did not do it |
| E15-10 | ✅ | A demo that is no longer on screen stops | switch tabs while one is playing and its next step builds into whatever you switched to — or throws, because the node it was going to wire up is not there |
| E15-11 | ❌ | A step shows where somebody would have clicked | lighting the dot *after* the node appeared was a caption on a magic trick. Superseded by `E15-12`, which fixes the cause | reported: things appear and wire themselves up and you cannot see where the click was. The port dots already know how to glow — that is how a wire being dragged shows its legal targets — so a step points at a port or at the palette row it came from |
| E15-12 | ✅ | The demo does what a person does, not what the model does | reported twice: it builds like magic and you cannot see where to click. `E15-1` made a step an action on the controller, which is why — nothing is ever clicked, so there is nothing to point at until after the fact. A step becomes an *intent* instead, and how it is carried out depends on who is watching: straight to the controller in a test, and through the real widgets, with a cursor and the real port menu, on screen |
| E15-13 | ✅ | A cursor you can follow | it moves to the thing, then the thing happens. Cause before effect is the whole of what was missing |
| E15-14 | ✅ | The words sit beside the thing, and Next with them | a line at the top of the screen and the action at the bottom is two places to look. The card follows the cursor, carries the button, and nothing advances on a clock — which retired `E15-7` as well |
| E15-7 | ❌ | Pace it by what it is saying | there is no pace to tune: it waits for a press. The question was how long a step should sit on screen, and the answer turned out to be "as long as you like" | a fixed delay per step reads as slow on a sentence and rushed on a table. Length of the caption is the obvious rule, and obvious rules about reading speed are usually wrong — worth measuring on somebody before writing |

## E8 — Quality

| id | P | Task |
|---|---|---|
| E8-1 | ✅ | Unit tests for every solver path (DAG, cycle, underdetermined, inconsistent, shortage, surplus) |
| E8-2 | ✅ | Golden real-world scenarios | the SPOM, the petroleum boiler, the oxylite chain and the coal farm, every figure worked out by hand before the test was run |
| E8-3 | ✅ | Property test: any solved graph satisfies mass balance within ε |
| E8-4 | ✅ | Widget/golden tests for the canvas |
| E8-5 | ✅ | Benchmarks in CI |
| E8-3b | ✅ | Mass-balance audit |
| E8-6 | ✅ | A guide to using it | `docs/USING.md`: the one idea, the controls in the order you meet them, and a section on what the app deliberately does not know |
| E8-7 | ✅ | The guide, reachable from inside the app | a ? in the toolbar renders `docs/USING.md` itself, copied into the assets and checked for drift the way the generated data is |
| E8-7a | ✅ | The guide closes when you click away | the pipelines menu and the recipe form always have; it was the one overlay that did not |
| E8-8 | ✅ | Rate-plausibility audit | a gram a second at the bottom, ten pipes at the top, and an allowlist that has to say why each exception is real |
| E8-9 | ✅ | Footprint and vocabulary audits | no building with no floor; no item nothing uses without a sentence saying what it is for |
| E8-10 | ✅ | The kanban audit | the board has to agree with itself: one row per id, a row behind every board entry, nothing offered in Ready that its own row calls finished, and no status the legend does not explain |
| E8-11 | ✅ | The guide is checked as a rendered thing | every heading reaches the screen, and nothing is written in Markdown the thirty-line renderer would hand the reader as punctuation |
| E8-12 | ✅ | The second reachability sweep | every public engine symbol against every call site in `lib/`: two things the engine worked out and nobody could read — what rounding costs the build, and which buildings the shopping list could not price |
| E8-13 | ✅ | Every sentence the app says, checked | 134 of them read against what the code does. Two named a figure the engine holds as a constant and would have gone on saying it after the constant changed |
| E8-14 | ✅ | The per-frame scan | `hasASplitToChoose` walked the whole edge list once per port, on every frame, and the answer that cost most was the usual one. One pass over the edges, and cached with the solve |
| E8-15 | ✅ | The rest of the per-frame work | connected components and the scoped totals were recomputed on every frame; measured at 300 nodes, cached, and the dropping is what the tests check |
| E8-16 | ✅ | The undo stack that grew while you arranged things | the cap lived in one of the two places that push to it, and not in the one a drag takes |
| E8-17 | ✅ | One place for each rule | three rules were written out in fourteen places between them, and one of the copies was already dead |
| E8-7b | ✅ | The guide is a list of topics, not a wall | twelve headings and three hundred lines arriving as one scroll. The headings are already in the file, so the split costs nothing and stays honest: pick a topic, read that topic, go back |
| E8-23 | ✅ | The guide says how food works now | and reading its "what this does not know" section found the Dehydrator stranded |
| E8-22 | ✅ | The eating nodes keep out of the way | 55 generated nodes landed in the group that lists things that cook, which is what the palette already solved for pumps |
| E8-21 | ✅ | The audit that would have caught the Mush Bar | a kitchen that makes 60 kg of food a cycle out of one machine is a batch mistaken for a rate |
| E8-20 | ✅ | Count the visits | GitHub Pages says nothing about who came. GoatCounter: cookieless, no personal data, so no banner — and the first network request this app has ever made, which the README has to stop being silent about |
| E8-19 | ✅ | The third reachability sweep | every public thing in `app/lib/` against every reader of it, tests included |
| E8-18 | ✅ | Golden builds for this week's data | fifteen recipes seeded in a week, each unit-tested against its own page and none of them checked as a chain |

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
