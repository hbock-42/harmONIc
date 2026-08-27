# What's new

What has changed in harmONIc, newest first. Written for somebody using it rather
than somebody working on it, so a week of small corrections is one entry and a
fortnight of quiet is none.

Every rate here comes from the game's wiki, and the entries say when one of them
turned out to be wrong — because a planner that was wrong last week and does not
admit it is worse than one that never claimed to be right.

## 27 August 2026 — Builds that would not open

Faults where the app was the problem, most of them in builds it had written
itself.

- A build could come back with wires it then refused to draw. The app works a
  share out by dividing one flow by another, which lands on 1.0000000000000009
  often enough, and it was rejecting that as "not between 0 and 1" — every wire
  to zero, and no way out but to draw the whole thing again. Builds already
  saved with one open again: there is nothing to redraw.
- **Use as little as possible** could lock a spare-power outlet shut, by putting
  a share of nothing on it. A plain SPOM would then not balance at any size,
  because the hydrogen the generator was no longer burning had nowhere to go. An
  outlet the answer does not need is left free now rather than closed.
- What the app suggests is now always something it can then solve. It used to be
  able to hand back an answer it called impossible a moment later, because it
  allows a port to keep a surplus while the ordinary sums do not. Where an
  answer really does leave something spare, the port is marked as venting, where
  you can see it.
- A count nothing sets now says **any amount** rather than a number. A
  spare-power outlet reading "0.0 W" reads as *no spare power*, when what it
  meant was that nothing in the build said how big the generator was — and the
  app cannot know until you say.
- A port whose wires already share out all of it now says so, instead of
  solving to negative amounts. Six wires taking a fixed share of one
  generator's power leave nothing for a seventh, and the sums could only
  balance by running it backwards — which spread to seven nodes, none of them
  the one at fault, under the advice "check the edge shares". It names the
  port and how much is left.
- **"I know my inputs, not my outputs"** now has an answer. Put a valve on each
  supply — the figure you have, which means *at most* — and ask what comes out
  for as much as possible. It works the whole build out inside those valves.
  It always could; it kept only the splits and threw the scale away, so the
  build came back as undecided as it started.
- A build with two loose ends can be given two amounts. Setting one used to
  clear every other amount in the same connected build — so the app would say
  it needed two and then make the second undo the first. It only replaces them
  once the build has a size, where another amount would contradict rather than
  complete.
- A supply whose amount is more than the build needs now says what is wrong.
  The field reads "I have this much" and the amount means *exactly this much
  flows*, so a supply you have plenty of contradicts the build rather than
  leaving a spare — set a pool of water to 10 kg/s beside a refinery wanting
  4.8 and nothing would solve. It says so, and says to clear the amount or put
  the figure on the wire as a valve, which does mean "at most".
- A build that cannot be sized yet points at its supplies. Being told to name
  an amount for the Sand output is no help to somebody planning from what they
  have — the amount is the thing they came to find out. Giving every supply an
  amount is what they do know, and it is often the whole answer.
- A build with two loose ends says it needs two amounts. It used to say "give
  an amount for one of: Sand output, Water output", which reads as a menu —
  and giving one left the build exactly as stuck, naming the other.
- Nothing comes out below zero without saying why. A build could report a Rock
  Crusher at minus five, and six other nodes downstream of it, each with its
  own line saying "check the edge shares" — true, and no help. It is one line
  now, naming the port that could not supply them, and not naming the nodes
  that merely inherited the problem.
- A wire's share counts the wires that are actually there. "Taking everything
  the port makes, since nothing else is asking for it" was said with two other
  wires asking for it: only the producer-driven ones were counted, so the
  consumer-driven ones were invisible to the sentence describing them.
- A build shared from a newer version says what it could not open. It arrives
  with a node this app has never heard of, and every wire that touched it goes
  too — which can be all of them. The note named the node and stopped there, so
  the build looked like boxes somebody had forgotten to join up. It counts the
  wires now, and says the likeliest reason: your app is older than the build.

**New.** There is a **Power Network** node. A grid in the game is one shared
bus, so two generators and three consumers should be generation minus
consumption — not six wires and an even split nobody asked for. Put one in the
middle, run the generators into it as *the producer*, and a Power output on the
end is what the grid has spare. Raised as the first issue anybody opened.

And it says when it has changed: a line at the top of the canvas counting what
is new since you were last here, and this list, showing only the part you have
not read.

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
