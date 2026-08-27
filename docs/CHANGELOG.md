# What's new

What has changed in harmONIc, newest first. Written for somebody using it rather
than somebody working on it, so a week of small corrections is one entry and a
fortnight of quiet is none.

Every rate here comes from the game's wiki, and the entries say when one of them
turned out to be wrong — because a planner that was wrong last week and does not
admit it is worse than one that never claimed to be right.

## 27 August 2026 — Three reports about being told the wrong thing

None of these was the arithmetic. All three were the app answering a fair
question badly.

- **"It lists every single node and it's hard to tell which one is the
  problem."** When a build cannot balance, the app tries venting each
  over-committed port in turn to find the one at fault. That search was
  capped at 24 ports and the build that was reported has 26, so it gave up
  and listed them all. It names the one port now — which, on that build, was
  the node its author had just added.
- **Sending the rest of a divided output somewhere no longer breaks the
  build.** Hanging an output node on a port whose lines already divide all of
  it left the new line with nothing to take, and the whole build was refused.
  A fourth line onto a three-way split now divides once more, which is what
  anybody drawing it means.
- **A share the optimiser meant as nothing is written as nothing.** It was
  writing 0.000000000000006 — six femto-per-cent — which starved whatever was
  on the end of that line while reading as 0 % on screen.

## 27 August 2026 — Every figure, where you can check it

**Figures**, on the toolbar: everything the app knows, grouped by what comes
out and sorted by how much.

- **What makes it** and **What eats it**: the same catalogue from either end.
  A figure means little alone and a lot beside its neighbours.
- A card for each way of getting a thing, two side by side where there is
  room, so two ways are the same shape and can be read against each other.
- The bar under a figure says how much of the best in its group that is.
- **Published** or **judged**, so you can tell the game's figures from ours.
- **×2 ×5 ×10** on a card, one card at a time — comparing two ways means
  holding one still while the other moves.
- Click what a recipe takes to go and look at that thing, which is how you
  walk a chain backwards.
- **Inspect** for the recipe whole, including **what it does to matter**: kg in
  against kg out, which is how a recipe that invents matter shows itself.
- Rates are per cycle, which is how the game quotes them, and a counted thing
  now says what it is counting — kcal, points of growth, eggs, gaskets —
  where it used to say a number and nothing else.
- **Wrong?** on a card opens a report with the recipe already named.

It is read off the data the solver is using rather than written down anywhere,
so it cannot be out of date.

## 27 August 2026 — A supply says what you have, or what flows

Two different things, and the app had one of them.

- **I have this much** is an amount, and always meant *exactly that much
  flows*. That is what gives a build its scale, and it is why a supply set
  higher than the build needs would refuse to solve.
- **Or at most this much** is new: a ceiling. The build takes what it needs up
  to it and says so if it needs more.

Put a ceiling on each supply and ask what comes out for as much as possible,
and you have "what can I make from what I have" — which took a long afternoon
to answer before.

## 27 August 2026 — The palette says what a thing is for

Every recipe already carried a sentence about itself, and the list showed only
its name.

- **Arbor Tree** and **Arbor Tree (grazed)** now say which is which — *the same
  plant, left for a critter to graze instead of harvested* — which was the
  first question anybody asked about this app.
- A recipe whose figures are a guess says so before you place it, rather than
  after.
- Supplies and outputs stay quiet: there are hundreds of them and their names
  already say what they are.

## 27 August 2026 — Being told about it

The notice that tells you a release has happened could not tell you about the
release that added it.

- On a first run the newest entry is recorded silently, because to somebody who
  has just arrived the whole app is new and none of it is news. On the day the
  feature shipped, every reader was on a first run.
- Saved builds are the evidence otherwise: work in this browser means you were
  here before there was a changelog, so the whole of it is new to you and you
  are owed the notice. Genuinely new readers still get nothing.

If this line is the first you have seen of any of it, that is the fix working.

## 27 August 2026 — Builds that would not open

Mostly faults where the app was the problem, and several in builds it had
written itself.

**Saying how big a build is.**

- **You can give a build as many amounts as it has loose ends.** Setting one
  used to clear every other amount in the same build, so the app would say it
  needed two and then make the second undo the first.
- It says **how many** it needs, rather than "give an amount for one of…",
  which read as a menu when it was a list of all of them.
- **An amount on a supply means exactly that much flows**, not "up to this
  much" — so a supply you have plenty of contradicts the build. It says so now,
  and says what to do instead.
- **"I know my inputs, not my outputs"** has an answer: put a valve on each
  supply — a valve means *at most* — and ask what comes out for as much as
  possible. It works the whole build out inside those valves. It always could;
  it kept the splits and threw away the size.
- A count nothing sets says **any amount** rather than a number. A spare-power
  outlet reading "0.0 W" reads as *no spare power*.

**Splits between wires.**

- A port whose wires already claim all of it **says so**, instead of solving to
  negative amounts spread across nodes that were not at fault.
- Where something does come out below zero, one line names **the port that ran
  out** — not the six nodes downstream of it, each told to "check the edge
  shares".
- **Use as little as possible** could lock a spare-power outlet shut, so a
  plain SPOM would not balance at any size.
- What the app suggests is now always something it can then solve. It could
  hand back an answer it called impossible a moment later.
- A wire's share counts the wires that are actually there. "Nothing else is
  asking for it" was said with two other wires asking.

**Opening things.**

- A build with a share of 1.0000000000000009 opens again — the app wrote those
  itself and then refused them. **Nothing to redraw**: saved builds work.
- A build shared from a newer version says what it could not open, and how many
  wires went with it.

**New.** There is a **Power Network** node. A grid in the game is one shared
bus, so two generators and three consumers should be generation minus
consumption — not six wires and an even split nobody asked for. Put one in the
middle, run the generators into it as *the producer*, and a Power output on the
end is what the grid has spare. Raised as the first issue anybody opened.

And it says when it has changed: a line at the top of the canvas counting what
is new since you were last here, and this list, showing only the part you have
not read. If you have builds saved here, that is all of it — you were here
before there was a changelog to read.

## 27 August 2026 — What the players found

A week of reports from the Oxygen Not Included Discord, and most of them were
right.

**Rates that were wrong.**

- The Marine Drill made a quarter of its sulfur, and none of its natural gas.
- An Orehull was sheared for ten times too much iron ore.
- A grazed Arbor Tree grew a tenth of what it grows.
- A Pip made half the dirt it makes.
- A Mixed Berry Pie was baked without its grubfruit, and Curried Beans without
  any beans.
- A Grubfruit Preserve had no sucrose in it.

**Things that were missing.**

- The Oakshell, whose molts are wood that costs no water — which is what lets an
  ethanol loop close.
- The Cuddle Pip, which you get whether you meant to or not.
- The Polluted Brine Vent.
- Kelpoles that something will actually take.
- Sublimation: slime, oxylite, polluted water and bleach stone, each costing the
  thing that offgasses instead of appearing from nowhere.
- Brine as irrigation for a Tublia, which drinks it as readily as polluted
  brine.

**The kitchen.** Every cooked dish is a material now rather than a number of
calories, so a Gas Range can take what an Electric Grill made and a Duplicant
eats a *meal*.

- 73 recipes across nine buildings.
- All 64 calorie figures read back against their source.

**Things that worked badly.**

- Two wires into one port used to split it evenly and not say so, which quietly
  doubled a build. It says so now, and says what to do about it.
- Asking twice for the least of something gave a different answer each time.
- A port marked as venting could be drawn from harder than it makes, and said
  nothing.
- "4.00 ×" of something asked you to build five of it.
- The palette folds: 428 of its rows are the supply, output and eating node that
  exist for every item, and they start out of the way.

## 26 August 2026 — Food

Plants grow crops rather than calories, so what happens to a crop is now
something you draw rather than something the app assumes.

- Eating is a node: one per food, under EATING in the palette.
- The Electric Grill, Gas Range, Deep Fryer, Sushi Bar, Smoker, Microbe Musher,
  Dehydrator and Rehydrator all know their recipes.
- A Mush Bar used to feed eight hundred Duplicants. It feeds one.

## Earlier

harmONIc went public in August 2026. Before that there is a repository full of
commits and no changelog, which is the honest way to say that nobody was reading
it yet.

---

*Adding an entry: put a new `## <day> <Month> <year> — <title>` section at the
top of this file, open it with one plain sentence — that sentence is what the
app shows under the heading in its list — and then use bullets, because six
things fixed reads as six things when it is six lines and as a wall when it is a
paragraph. Run `tool/copy_docs.sh`.*

*Once an entry has shipped, anything done after it goes in a **new** entry, not
as another bullet in that one. The app decides what somebody has read by
matching the heading, so work added to an entry they have already read is work
they will never be told about — which is exactly what happened on the day this
file was written. Editing a shipped body is for corrections.*

*Entries run newest first, and several in one day is normal: the date is not
what tells them apart, the title is. That is why a heading is both. Two entries
must never share a heading — the app decides what somebody has already read by
matching one, so a duplicate would make one of them unreachable and the other
permanent, and renaming a shipped heading shows everybody the whole history
again. Bodies can be edited freely; headings are fixed once they ship.*

*Ship nothing here for a change nobody using the app would notice. A release
with no entry says nothing, which is the point.*

*The other half of that rule is the one that gets forgotten: anything somebody
reported gets an entry, always. They told us it was wrong, and being told it is
fixed is the whole of what they get back. Three fixes shipped without one on the
day this file was written, two of them to bugs players had reported — so the
entry goes in with the fix, not after somebody notices it is missing.*
