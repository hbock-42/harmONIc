# What's new

What has changed in harmONIc, newest first. Written for somebody using it rather
than somebody working on it, so a week of small corrections is one entry and a
fortnight of quiet is none.

Every rate here comes from the game's wiki, and the entries say when one of them
turned out to be wrong — because a planner that was wrong last week and does not
admit it is worse than one that never claimed to be right.

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
paragraph. Run `tool/copy_docs.sh`. Entries are newest first and headings are
identifiers once shipped: the app decides what somebody has already read by
matching a heading, so renaming one shows them the whole history again. Ship
nothing here for a change nobody using the app would notice — a release with no
entry says nothing, which is the point.*
