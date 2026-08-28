# What's new

What has changed in harmONIc, newest first. Written for somebody using it rather
than somebody working on it, so a week of small corrections is one entry and a
fortnight of quiet is none.

Every rate here comes from the game's wiki, and the entries say when one of them
turned out to be wrong — because a planner that was wrong last week and does not
admit it is worse than one that never claimed to be right.

## 28 August 2026 — A build that feeds only itself no longer crashes

A loop whose parts are fed by nothing but each other comes out below zero,
and the app has always said so. It named what was drawing too hard — and
in this case there is nothing to name, because everything feeding the loop
is in the loop. The empty list took the solver down.

It now says what is actually the matter: a loop with nothing coming into
it from outside, so there is nothing to start it off, and something in it
wants feeding from elsewhere or an amount of its own.

Found by pointing four hundred generated builds at it rather than by
anybody running into it — sixteen of them crashed.

## 28 August 2026 — Flow figures no longer disappear behind cards

Wires are drawn under the cards — that is what lets one pass behind a card
without cutting a hole through it — and the figure on a wire was drawn with
it. So a figure that happened to land on a card was not merely hard to
read. It was not on the screen at all, and nothing said one had gone.

Eight of forty-nine on one build sent in, five of fifty-two on another.

Each figure now slides along its own wire until it is in clear air. Along
the wire rather than off to one side, because a number floating beside a
line belongs to no line in particular, and saying which line is the whole
job. A figure with nothing in its way does not move: the middle of a wire
is where the eye looks for it.

Where no spot on a wire is clear of both the cards and the other figures,
clearing the cards wins — crowded and readable beats tidy and invisible.

## 28 August 2026 — Nothing is placed on top of anything any more

Once the app could spot a buried card it was worth asking how they got
buried, and two of the four ways a card gets a position never checked.

Clicking a card onto the canvas put it exactly where you pointed, even if
that was on top of something. It now lands below whatever is there.
Dropped into clear space it still goes precisely where you put it.

Pasting was worse. A copy arrived a fixed short step down and to the
right, which is right on an empty canvas and wrong on top of the build it
came from — pasting one into itself left every card between 55 and 64 per
cent buried, a second build almost exactly on the first with both sets of
wires crossing each other. A pasted build now comes down far enough to
clear what is already there, moving as one piece so the arrangement it
copied survives.

## 28 August 2026 — Tidy no longer leaves cards on top of each other

Reported, and easy to confirm once there was something to confirm it with:
tidying a build could put two cards in the same place. Two pairs on one
build sent in, four on another — every one of them within a column.

Arranging a column moves the busiest cards first and lets the rest take
what room is left, and a card that found no room stayed exactly where it
was, which by then could be underneath something. They are now pushed
apart, moving each one as little as possible rather than simply shoving
everything downwards.

It costs a little droop — about a tenth more across the test corpus. Some
of the flatness it had was bought by letting two cards share a spot, which
makes the wire between them perfectly straight and the build unreadable.

## 28 August 2026 — A card hidden under another card says so

Found while measuring the new wire routing rather than from a report: a
build sent in had its Plastic output card lying entirely inside the Glo
Squid card. Nothing said so. You cannot click it, cannot read its figures,
and the wires into it appear to stop in mid-air — which is the sort of
thing that gets reported as a wire bug, because from the outside that is
exactly what it looks like.

The banner now names it, names what is sitting on top of it, and offers to
move it clear — down past everything else in the way, not merely past the
one card named. It is offered rather than done: two cards on top of each
other is sometimes deliberate, and an app that quietly rearranged your
canvas would be worse than one that mentions it.

Only when most of a card has gone, including its name. Cards clipping each
other by a few pixels is untidy rather than wrong, and a warning that fires
on every crowded build is one nobody reads.

## 28 August 2026 — Wires go round the cards instead of under them

Reported with a picture: an Electrolyzer above a Hydrogen Generator,
power going back up and hydrogen coming down, and both wires drawn
straight through the middle of both cards. A wire under a card is not
merely untidy — you cannot tell which of the two things it vanished
between it actually came out of.

A wire that would cross a card it does not belong to now goes round it,
by the shortest way round, and keeps a little clear of the edge. Wires
with nothing in the way are untouched, which is most of them. Long wires
across a whole screen of cards are included — those were the ones still
being drawn through things, because a wire that passes near forty cards
is in the way of about two of them, and only those two count.

This includes the two cards a wire is plugged into. A wire between a
generator and the thing it powers leaves the right-hand edge of one and
has to reach the left-hand edge of the other, so it travels backwards
across the full width of both — the case where going straight through is
most obvious, and the one that was left out.

While you drag a card, the wires attached to *that card* go back to plain
curves and find their way round again when you let go. Every other wire
stays where it is: working out the way round is far too much to redo
sixty times a second, and a route drawn for where a card was would leave
the wire hanging in space away from its port.

## 28 August 2026 — Dragging a card no longer re-does the arithmetic

Moving a node re-ran the whole solve, on every frame of the drag — to
arrive back at exactly the figures already on screen, because nothing in
the solver has ever read where a card sits.

Measured per frame of a drag, on builds people have sent in: a 14-node
build went from 0.7 ms to about a microsecond, a 38-node build from
5.4 ms, and a 41-node build from 8.7 ms. A frame is 16.7 ms, so the
largest of those was giving up half of every frame. The cost is also flat
now — how big the build is no longer changes what a drag costs, which is
the right way round, since big builds are the ones worth rearranging.

Nothing else changes. The numbers were never wrong; they were being worked
out again sixty times a second for no reason.

## 28 August 2026 — A node drawn harder than it makes says OVER

Reported: a refinery making 408 g/s of petroleum with 2 800 g/s drawn off it
showed nothing at all, while the node it fed lost its NEEDS mark and looked
settled.

The marks looked for a *leftover* — something spare, something wanted from
outside — and being over-drawn is the opposite of one. It is marked now, in
red, and first: it is the only one of the four that means something is wrong
rather than merely open. Supplies get it too, which the others do not: "you
said you have a kilogram a second and this build wants four and a half" is
worth saying, where "this supply comes from outside the build" is not.

## 28 August 2026 — Undo takes the note with it, and the note is English

**"Since the amount on the Duplicant"** was not a sentence. The phrases naming
an edit were written for one place and reused in another that does not take a
noun; they are all *"setting the amount on the Duplicant"*, *"drawing the line
from A to B"* now, which both places take.

And undoing an edit left the note about it on screen — a line about a build
that no longer existed. Undo and redo clear it.

## 28 August 2026 — What your last edit cost

At the end of the totals: **since the amount on the Duplicant — power 1.2 kW →
−340 W, dupe time 80 s → 240 s.** What one change did to the figures, named by
the change.

The app already said when an edit *broke* a build. This is the other half of
the same question, for the ordinary case where nothing broke and the totals
simply moved. Only what actually moved is listed, and an edit that changes no
figure — dragging a node about — says nothing at all.

## 28 August 2026 — A code that will not open says why

Three kinds of not-opening, told apart: **not a share code at all**, **cut
short**, and **damaged** — a character changed in transit. The last two look
identical to the eye, which is why the app had been calling both of them "that
does not look like a pipeline" and sending people to look for the wrong thing.

The message sits under the box it is about now, in the colour the app uses for
things going wrong. It was below a fold about recipes, in the same grey as
"Share code copied."

## 28 August 2026 — A box to paste a build into

**Paste build** reads the clipboard, and a browser often will not let it. There
is a field beside it now, so a share code has a way in whatever the browser
thinks.

And a code that will not open says which kind of not-opening it is. A share
code damaged in transit — one character lost to a line wrap or a bad copy —
used to be reported as "that does not look like a pipeline", which sends you
looking for the wrong problem: a broken code looks perfectly fine to the eye.

## 28 August 2026 — A ceiling means the supply, not each of its lines

**"At most this much" was being written onto every line out of a supply**, so a
supply feeding two things gave twice what you allowed it. A build capped at ten
kilograms of ore a second answered fifteen kilograms of iron — out of ten.

The ceiling belongs to the supply now. Builds saved with the old one still read
it, and the app says so when a build needs more than the ceiling allows,
exactly as it does for a valve on a pipe.

## 28 August 2026 — What can I make from what I have?

One button on an output node. It rereads every supply's amount as a ceiling
rather than as exactly-that-much-flows, and divides the build to give you the
most it can — the difference between *"I have ten kilograms of water a second"*
and *"ten kilograms a second must move"*.

All of that was already possible and written down in the guide, and nobody had
ever found it there. Asked twice in a week in different words.

## 28 August 2026 — A build fits in a message again

Share codes are compressed. A build that came to twenty-one thousand
characters is now under four thousand, which is the difference between a file
somebody has to download and a line they can paste — or a link they can click,
since the report form carries the build in its URL when it fits, and until now
it never did for a build worth reporting.

**Every code ever made still works.** Nothing needs re-sharing: the old ones
are read by the absence of a compression header, so months of codes in chat
logs and issue threads open exactly as before.

## 28 August 2026 — An amount that goes says that it went

Setting an amount on a build that has already settled clears the amount that
settled it — two amounts on a build with no slack would have to disagree. That
was right and it happened without a word, so the first SET simply vanished. It
says so now, and ⌘Z puts it back.

Where a build *does* have slack — a line carrying the rest, say — it was never
a problem: both amounts are kept and both hold. That is the case somebody
wrote an external tool to get at.

## 28 August 2026 — What broke it

When a build that was adding up stops adding up, the banner names the edit that
did it: *"This was solving until the line from the Electrolyzer to the
Duplicant."* — with an **Undo that** beside it.

Every report of a broken build has been phrased that way — *adding X did Y* —
and the app made people prove what they already knew. It knows too: the undo
stack holds the build that was working a moment ago.

It stays until the build is whole again, because edits made while hunting for
the cause are not the cause. And it says nothing while a build is merely
unfinished: half of drawing one is having amounts nobody has given yet.

## 28 August 2026 — Why this many

Select a node and it says why its amount is the amount it is. *"You set this
one."* — *"It follows from the amount you set on the Marine Drill."* — *"It is
settled by its own oxygen: 1.00 kg/s leaves and each one makes 888.00 g/s."*

Every question anybody has asked about a figure in this app has turned out to
be a question about which equation settled it, answered by hand each time. The
solver has always known: one row of its arithmetic pins each count down, and it
was throwing away which.

## 28 August 2026 — Two ports at fault, and a button that admits what it draws

- **"No single port explains this one: it takes two."** When a build cannot
  balance, the app tries venting each over-committed port to find the one at
  fault. Where none of them is, it now tries pairs and names the two. Past
  that it says outright that no single port is the problem — which is worth
  more than the list, because it stops you hunting for a culprit that is not
  there.
- **The button says what it draws.** *Draw 3 supplies* had been drawing output
  nodes too and never admitting it, which is why somebody asked for an "add
  missing outputs" button that was already there. It reads *Draw 1 supply and
  2 outputs* now.

## 28 August 2026 — Things you can click look like it

Reported: *"there is lots of clickable that doesn't show they are clickable in
the Figures panel."* Every filter chip, every ×2, the fold headers, the note,
the pills for what a recipe takes, and Inspect and Wrong? — all of them took a
tap and showed nothing on the way over. They light under the pointer now, and a
test walks the whole editor and fails on any tap target that stays silent. It
found two more in the palette, and a search box that never showed a text
cursor.

## 28 August 2026 — Nodes say what they are quietly doing

Asked for after a build turned out to be unbalanced by a port nobody could see:
**VENT** where a port is set to throw something away, **NEEDS** where something
a node eats comes from outside the build, and **SPARE** where something it
makes leaves without a wire. Not on supplies and outputs, where all of that is
the point of them, and not for heat, which is where heat goes.

## 28 August 2026 — Wrong? actually opens something

The button on every figure had never been connected to anything, so it was
never on screen. It opens a report with the recipe and all of its rates
already written out — spotting a ten-times slip should not mean transcribing
the row you spotted it in.

## 28 August 2026 — Whatever is left

A wire can now carry **whatever is left**: what its port makes, less everything
else leaving that port.

It is the third thing anybody means and the one that could not be said. A
generator powering three buildings with an output node for the spare was
neither a consumer with a demand of its own — nothing said how much it wanted —
nor a fixed share of the generator, which took the lot and starved the three.
Three reports were this one gap.

- Set it on any wire under **Who decides the amount**.
- Drop an output node on a port that already feeds something and it is chosen
  for you, with a line saying so that ⌘Z undoes.
- It follows: change what the neighbours take and the surplus moves with them.
  There is no share to work out again.
- **Get as much as possible** answers inside it and leaves it alone, rather
  than freezing today's number into a share.
- Ask for more than a port makes and it says so, rather than running the wire
  backwards.

It costs one thing, and the app says it: the producer is no longer sized by
what draws from it, because the surplus absorbs any difference. Give the
producer an amount, or give the output node one — either settles the other.

## 28 August 2026 — A loose end is not a loose build

Hanging an output node on a build that solved said *"nothing sets the size of
this build, so every amount in it could be anything"* — while every figure on
screen was still right and unchanged. Where the build already has amounts on
it, it now says which thing has no size yet and leaves the rest alone.

## 28 August 2026 — Two more from the same build

- **Any wood is any wood.** An Ethanol Distiller fed Lumber would not also
  take Gum Wood, even with the material left on *Any*. A class port was being
  settled by the first wire into it — right for a Metal Refinery, whose
  refined metal *is* the ore it was given, and wrong for everything else. Only
  the four recipes whose output follows their input decide now.
- **"Promised twice over"**, a warning with a button that settles it. A
  consumer-driven line with no share of its own brings a port's *whole*
  demand, so anything pushed into the same port on top of it has nowhere to
  go — and the amounts there go to zero. That is what linking a Cuddle Pip's
  dirt back to an Arbor Tree already fed by a Compost was doing.

## 27 August 2026 — Output nodes, and what an even split really splits

- **A second wire into an output node joins the first**, producer-driven, and
  the app says so in a line you can undo. An output has no size of its own, so
  two consumer-driven lines into one read their shares as shares of each other
  — which is never what a second line means.
- **Where that has already happened, it is a warning with a button that
  fixes it.** An output node has no size of its own, so two consumer-driven
  lines into one read their shares as shares of *each other* — which quietly
  holds every supplier feeding it to the same amount. That is where "unsure
  why the negative draws keep happening" came from. It is said whether or not
  the build solves, because a build with it can solve perfectly well and still
  be wrong, and **Set all 4 to the producer** does it in one step you can undo.
- **The tutorial was telling you the wrong thing.** "Let it choose the split"
  said the app had split the ore evenly. It had not: the ore goes 3.33 one way
  and 6.67 the other. What comes out even is the *iron*, held there by exactly
  the trap above. The same shape people were reporting was sitting in the
  app's own worked example, described backwards. The demo says "let the
  producer decide" now, which is what makes its own sentence true: the ore
  really does split 5 and 5, for 7.50 kg/s of iron, and asking for the best
  still gets 10.00.

## 27 August 2026 — Finding things

Two ways to stop hunting a canvas bigger than the window.

- **⌘F finds a node.** Type and the first match comes to you; Enter for the
  next, ⇧Enter for the one before, escape to put it away. It searches what a
  node is called and also what it makes or takes, so "sulfur" finds the whole
  chain and not only the node with the word in its name.
- **A message that names something offers to show it.** Every port and every
  wire a problem mentions is now a button under it, and clicking one selects
  that thing and brings it into view. A message naming six ports used to be
  six places to go and look for by eye.

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
