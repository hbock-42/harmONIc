# Using harmONIc

The whole app is one idea: **draw what you are building, say how much of one
thing you have, and everything else follows.** Everything below is a detail
hanging off that.

In the app it opens as a list of these headings, so you can go straight to the
one you want; here it is one page, which is what a file is for.

Read it in order the first time. After that, the last section — what this
deliberately does not know — is the one worth remembering, because the app is
most misleading where it is most confident.

## Drawing a build

Pick something from the palette on the left and it appears on the canvas.
Buildings are grouped by what they are for; **My builds** at the top is where
your own saved builds go, and **Supply** and **Output** at the bottom are the
edges of a build — "water comes from somewhere else", "the oxygen goes to the
base".

Click a group's name to fold it away, or to open one that starts folded. Three
do: **Supply**, **Output** and **Eating**, which have one node per item and one
per food and are 428 of the roughly 700 rows in the list. The number beside
each name is how many are behind it. A search shows what it finds whatever is
folded, and clearing the search puts the folds back.

Wire two nodes by dragging from one port dot to another. Or click a port dot
and pick from the list: it shows everything that could plug in there, places it
beside the node and connects it in one move. That list obeys your pack filters,
so nothing is offered that you cannot build.

Search the palette by what you want rather than by what it is called: typing
**oxygen** finds the Electrolyzer, and says *makes oxygen* under its name. What
makes a thing is listed before what eats it, and a name that matches outright
comes first of all.

**Showing** at the top of the palette is what you own. Turn off a pack you do
not have — Frosty, Prehistoric, Aquatic, or Spaced Out, which the other three
sit on top of — and everything from it leaves the list, including the supplies
for its materials. **Wild** is the other switch: a wild critter or plant is the
same thing left untended, laying a tenth as often and taking nothing, and the
list hides those until you ask for them.

**Draw N supplies** on the toolbar appears whenever something is unfed. One
press puts a supply or output node on every loose port, so the edges of the
build become things you can click, price and give a temperature to, instead of
a line in the totals.

## Saying how much

Select a node and fill in **I have this many** (buildings) or **I have this
much** (a supply's rate). That one number sizes the whole build.

A supply can be told what is in store instead — *"or say what you have in
store"* under the amount. Two tonnes of coal to last twenty cycles is 167 g/s,
and the build is sized to that. It answers "what will this last me" rather than
"what rate do I have", which is how you think about a stockpile you found.

**One amount per build.** Two builds sharing a canvas each get their own; giving
an amount to one leaves the other alone. If nothing is set, the app says so and
names what to set rather than guessing.

## Where the numbers go

The bar along the bottom is the totals for **the build you are working in** —
whichever build holds your selection. With nothing selected it shows the whole
canvas and says so. Two builds added together describe neither, so it is always
labelled.

On a node:

- **needed** is the exact ratio, fractions and all. **build** is how many you
  place, rounded up, and **busy** is how much of what you built gets used.
- A **critter, plant or Duplicant cannot idle.** Where a machine you half need
  simply runs less, the thirteenth Hatch eats like a Hatch. The inspector says
  what the spare one costs you.
- **going from 3 to 4** is what one more would buy and cost, worked out by
  solving the build again rather than estimating.
- **as built**, in the bottom bar, is what all that rounding costs the build.
  The other figures there are the exact ratio; the thirteenth Hatch you had to
  place eats like a Hatch, so a ranch needs more raw mineral than the ratio
  says and gives back more coal. It appears only when something had to be
  rounded.
- A building **nobody has priced** — one of your own recipes, until you give it
  a cost — is named in the bar rather than left out of the total in silence.
- **to build** is the shopping list for the ones you place. A part counted in
  ones rather than kilograms says what one costs beside it — four gaskets, and
  the 200 kg of plastic behind them.
- **What to build it out of**, when what runs through a building is hotter than
  the 75 °C a bare one tolerates: it names which of the materials the recipe
  allows survive that. An Electrolyzer is 200 kg of any metal ore, and at 95 °C
  only Gold Amalgam holds. A building the game rates itself, like a Steam
  Turbine at 1 000 °C, is not asked the question, because no choice of metal
  changes it.

## Things you can tell it

- **Runs** — a building on a sensor runs part of the time. The ratios do not
  change; you need more of them standing there. Not offered for critters,
  plants or geysers, none of which have a switch.
- **Assume active** — a geyser's activity, which is rolled when the world is
  made. Presets cover the band, and the field takes the exact figure Field
  Research gives you. A geyser rolls *two* numbers though — how often it is
  awake, and how much it emits while it is — and the shipped rate folds both
  into a lifetime average at a middling roll. So there is a second field: **what
  yours averages**, in g/s, for when you have measured it rather than guessed
  the percentage. They are one number wearing two hats; setting either shows the
  other.
- **Arrives at** — what temperature a supply brings its material in at. A
  build's temperatures have to start somewhere and the game cannot know yours.
- **Metal ore used** / **takes** — which material a recipe that accepts several
  is using. A Metal Refinery takes any ore; a Smoker burns wood or peat. Left
  unset it stays generic, which is the right answer until something downstream
  cares — and if you wire an Iron Ore supply into it, that *is* something
  downstream caring: the ports rename themselves to Iron Ore and Iron, and a
  Copper output will no longer connect. Iron ore refines into iron and nothing
  else, whether or not anybody said so out loud.
- **Takes** on a wire — how much of a producer's output that line gets, when one
  output feeds two things. "An even split" is a real answer, not a default
  nobody chose. Or you can leave the splits alone and let the app work them out:
  see *Letting it choose* below.
- **Valve** on a wire — a cap on what that line may carry. It does not change
  what the build needs, because the solver works out what it needs: it tells you
  when the build has outgrown what you allowed. Asking an output node for as
  much as possible does work inside your valves, since the optimiser can hold a
  cap where the solver cannot.
- **Vent** on a port — this output goes nowhere on purpose. Without it, a port
  making more than anything takes reads as a contradiction rather than as spare.

## Letting it choose

Where a build divides and nobody has said how, the app splits evenly. That is a
fair guess and rarely the best one, so you can ask for the best instead.

Select an **output** node and press **Get as much as possible**: it works out
the division that delivers the most of that item. Select a **supply** node and
press **Use as little as possible**: the division that spends the least of it
while still delivering everything you asked for. Ten kilograms a second of ore
through a refinery and a crusher gives 6.7 kg/s of metal split evenly, and 10
through the refinery alone.

The two are asked in opposite orders, which is worth knowing before you try the
second one. *As much as possible* needs an amount on the **supply** — you have
ten kilograms of ore, what is the most metal that makes. *As little as
possible* needs one on the **output** — you want five kilograms of iron, what
is the least ore that does it. An amount on the node you are asking about is
not an answer to either: with nothing wanted, the least ore is no ore, and the
app says so rather than emptying the build to prove it.

**LEAST**, beside net power, heat or floor in the bottom bar, asks the same of
the build as a whole: the splits that draw the least, emit the least, or stand
on the least. The three rarely agree — a Rock Crusher draws a fifth of a Metal
Refinery's power and eats twice the ore for the same metal.

All of them write what they chose onto the wires as ordinary shares, so
afterwards it is a build like any other: you can see the splits, change them,
and undo the whole thing. And all of them say when there is no answer rather
than inventing one — nothing limits the build, or nothing has been asked of it,
or two amounts you set contradict each other.

## Feeding people

A dish is a material. An Electric Grill makes **kilograms of Frost Bun**, not
calories, and a Gas Range takes two kilograms of Gristle Berry the way a Kiln
takes two hundred of wood. That is what lets a kitchen be drawn at all: five of
the Gas Range's twelve recipes cook something the grill made first.

So somewhere the kilograms become a meal, and that somewhere is a node of its
own — **Eating Frost Bun**, under EATING in the palette. One per food. Click the
grill's output dot and it is the first thing offered.

If you only want to know how many people a farm feeds, that is one extra node
and nothing else changes: crop → grill → eating → Duplicant, and the Duplicant
still eats calories as it always did. If you want to cook, the chain carries on
through the Gas Range instead and the calories appear at the end.

A Duplicant eats 1 000 kcal a cycle. A Mush Bar is 800, so it takes 1.25
Microbe Mushers to keep one person fed; a Frost Bun is 1 200 and a Uni is 7 200,
which is the densest food in the game.

## Planning from what you have

Saying what you *have* — 180 g/s of natural gas, a geyser's output, a stockpile
— sizes everything that follows from it. It does not size everything: where one
thing feeds several, how much goes where is a choice rather than arithmetic, and
the app will not invent it.

A supply asks you two different questions and they are both on the node:

- **I have this much** is an amount, and it means *exactly that much flows*.
  It is what gives a build its scale — a geyser at 1800 g/s sizes everything
  downstream of it. A supply set higher than the build needs contradicts the
  build rather than leaving a spare.
- **Or at most this much** is a ceiling. The build takes what it needs up to
  it and says so if it needs more. Nothing is sized by a ceiling; it only
  says what you have.

**If you know your inputs and not your outputs**, use the second and then ask:
put a ceiling on each supply, select what comes out, and press **Get as much as
possible**. It works the whole build out inside those ceilings.

It works out the whole build inside those valves and writes the answer down, so
the amount you did not know is the one it gives you back.

**An amount on a supply means exactly that much flows.** Not "up to this much".
So give an amount to the supplies you are actually short of — the geyser, the
gas fissure, the thing you are planning around — and leave alone the ones you
have plenty of. A supply with more than the build needs is a contradiction, not
a spare: set a pool of water to 10 kg/s and a refinery wanting 4.8 will refuse
to solve.

Left alone, a supply is asked for what the build needs and tells you the answer,
which is usually what you wanted from it. Where you really do mean "at most",
put the figure on the wire as a **valve**.

You can give a build as many amounts as it has loose ends — the message tells
you how many. A further one, once it has a size, moves the scale rather than
adding to it, because another amount then contradicts rather than completes.

Where something is still divided after that, three ways to say how:

- **Say how much you want** of what comes out, on any node downstream.
- **Say the split**, on the wires, as shares.
- **Ask an output node for as much as possible**, and it works the split out.
  This one needs something to be limiting it already — with every supply left
  unset there is no most to be had, and it will say so rather than guess.

## Power

A grid in the game is one shared network: every wire that touches is the same
bus, and *which generator feeds which building* is a question the game never
asks. Wiring each generator to each consumer asks it, and the answer is a guess.

So there is a **Power Network** node. Put one in the middle, run the generators
into it set to *the producer* — each hands over everything it makes — and take
everything that draws power off it. A **Power output** on the end is what the
grid has spare. Two separate grids means two of these.

It costs nothing and stands nowhere. It is the wires you were going to run
anyway.

## What can I make from what I have?

The opposite question to the one the app is built around, and a fair one. Put
an amount on each supply — the water you have, the ore you have — select what
you want out of the build, and press **What can I make from what I have?**

It rereads those amounts as ceilings rather than as exactly-that-much-flows,
which is the difference between "I have ten kilograms of water a second" and
"ten kilograms a second must move", and then divides everything so as to give
you the most it can. One press, one undo.

The button only appears where the question makes sense: on an output node, in
a build whose supplies have amounts on them.

## Wires

A wire is **pull** by default: the consumer decides, and the producer is sized to
cover it. **Push** is the other way — this line takes a fixed share of what the
producer makes, and the rest is somebody else's.

**Whatever is left** is the third, and the one you want for a surplus. A
generator powering three buildings with an output node for the spare is neither:
the output node has no demand of its own, and a fixed share of the generator
would take the lot and starve the three. Set that wire to *whatever is left* and
it carries the generator's output less everything else on that port — and it
keeps doing so when the three change, with no share to work out again. It costs
one thing: the generator is no longer sized by what draws from it, since the
surplus absorbs any difference, so something else has to say how big it is.
Give the generator an amount, or give the output node one — either settles the
other.

**Two wires into one port** need saying out loud. With nothing else to go on
the app splits that port's demand equally between them, which is rarely what
anybody means. If you are feeding an Arbor Tree from a Petroleum Generator's
own polluted water *and* topping it up from somewhere else, set **both** wires
to *the producer*: each then hands over what its own end makes, and the supply
covers whatever is left. Pinning one end and leaving the wires alone gives you
twice the trees, because the generator's 750 g/s is read as half of what they
drink.

A wire that would cross a card it has nothing to do with goes round it
instead. While you drag a card, its wires straighten out to plain curves and
find their way round again when you let go.

A node says what it is quietly doing. **OVER** means more is being taken from
one of its ports than it makes — the usual reason a build will not add up, and
the only one of these marks that means something is wrong. **VENT** means a port
on it is set to
throw something away, which is a decision you made and nothing else on the
canvas shows. **NEEDS** means something it eats arrives from outside the build,
and **SPARE** means something it makes leaves without a wire.

**None of the three is an error.** An unconnected port is how a build says
"this comes from somewhere else" — it is what makes a piece of a base worth
saving and pasting into another one, and the totals count it as an input or an
output rather than pretending it is not there. The marks are there because a
port you *thought* was connected and is not looks exactly like one you meant to
leave open, and that is what makes a build quietly fail to balance. Heat is
left out: heat leaving a building is where heat goes.

Select a node and it says **why** its amount is what it is. Every count in a
build is settled by one thing — an amount you typed, or a port whose arithmetic
has to come out — and the app names it: *"It is settled by its own oxygen:
1.00 kg/s leaves and each one makes 888.00 g/s."* When nothing settles it yet,
it says that too, which is the same thing the banner is asking you for.

The number on a wire is its flow. Click it to switch every rate in the app
between per second and per cycle. Select a wire and it says what carries it —
how many pipes or wires, since a ratio that balances on paper is unbuildable at
40 kg/s down one pipe — and what temperature it arrives at, and what a pipe
would have to be made of to survive it.

A hot or cold wire also says what it is worth in cooling: 10 kg/s of 95 °C
water carries 2 925 kDTU/s more heat than the same flow at 25 °C, which is five
Aquatuners' worth. That is the *size* of the thing, not a claim about where the
heat lands — a bare pipe gives it to the room it runs through and an insulated
one carries it onward, and nothing here knows which yours is.

## Arranging

**Tidy** lays the build out left to right. It arranges each build on the canvas
separately, orders the columns so wires cross as little as possible, keeps a lane
clear for a wire passing a column, and slides nodes so wires run flat. With
several nodes selected it tidies only those, so part of a build arranged by hand
survives tidying the rest.

**Fit** frames everything, or just the selection. Arrow keys nudge by a grid
cell, eight with shift. Drag a node to the window edge and the view follows.

Dragging on empty canvas draws a box and selects what it touches. To move the
view instead, hold **space** and drag, or use the middle mouse button, or scroll
with two fingers — three ways, because a plain drag is worth spending on
selection and taking it away from panning would be unkind without them.

**☀ / ☾** on the toolbar switches between the dark and the light look, and shows
what pressing it gives you rather than what you are already in. The choice is
remembered. The light palette is not the dark one inverted — every colour is
picked for the background it sits on, because a hue that reads on near-black is
usually too pale to read on near-white.

## Checking the figures

**Figures** on the toolbar lists what the app knows, grouped by what comes out
and sorted by how much. It is not a document — it is read
straight off the data the solver is using, so there is nothing to be out of
date.

Read down a list rather than across it. Two things that make the same stuff
should be within reach of each other, and the one that is not is the one to
check.

- **What makes it** and **What eats it** are the same catalogue from either
  end. A figure means little alone and a lot beside its neighbours.
- **Cards, Rows, Table** — how much of each row to show. Table is for scanning
  a column; cards are for reading one.
- **Published** or **judged** — whether a figure is the game's or ours.
- **×2 ×5 ×10** scales everything at once, for checking a ratio without doing
  the multiplication.

Click a row to see that recipe whole: what it takes, what it gives, and what it
does to matter — how many kilograms go in against how many come out. A recipe
that makes matter is not always wrong (a Hatch gives back half of what it eats,
and that is the point of it) but it is the first thing to check.

If a figure is wrong, **wrong?** on the row opens a report with the recipe
already named.

## What has changed

The app says so when there is something new to read, once, with a line at the
top of the canvas saying how many changes there have been since you were last
here. Click **What's new** to read them, or **Dismiss** — either way it does not
ask again.

What opens is **only what you have not read**: one change is one entry, not the
whole file. **Show everything** is there for the rest, and the panel opened from
the foot of this guide starts there — because looking up what changed last month
is a different question from being told what changed today.

It is driven by `docs/CHANGELOG.md` rather than by the build: a deploy that
fixed a typo has nothing to tell you, and the app would rather say nothing than
teach you to dismiss it without reading. Arriving for the first time shows
nothing at all, since all of it would be new.

The notice never comes back once it has been answered, so the way in afterwards
is at the foot of this guide, next to the build number — which is the same
question asked twice: *which build is this, and what changed in it*.

## Being shown

**Watch a demo**, at the foot of this guide or on an empty canvas, builds one
in front of you and says what it is doing. It is offered once on a first visit
too, as a line at the top with *Show me* and *No thanks* — an offer, never
something that starts playing at you. It is not a video: every node it
places and every amount it pins is a thing you could have typed, and every
figure it quotes comes out of the solver as it goes — which is why a test can
check that what it says matches what it does.

It does not play itself. Each step waits on **Next**, which sits in the card
beside whatever is about to be clicked — so the words, the button and the thing
they are about are all in one place, and nothing moves on while you are reading
a number. It runs in a tab of its own, so whatever you were building is
untouched, and **Leave** throws the demo's build away rather than leaving it in
your list.

## What leaves your machine

Nothing you draw. Builds live in the browser's own storage, and the only way
one goes anywhere is if you send it — a share code you copy, or a bug report
you choose to attach it to.

The page itself is counted, by GoatCounter: how many people opened the site and
what page they came from. No cookies, no identifier, nothing about the build in
front of you. It is the one request this app makes to anywhere, which is why it
is written here rather than buried.

## When it is wrong

The foot of this guide has **Report a bug** and **Suggest something**. Both
open a form with the version, what you are running it on, and — the useful
part — **your build** already in it, as the same share code the pipelines menu
copies. One paste at this end and the build that broke opens here.

The code holds your build and nothing else: no name, no account, nothing about
your machine. It is in the form where you can see it, so delete it if you would
rather describe the build in words. A build too big to travel in a link goes to
your clipboard instead, and the app says so rather than changing your clipboard
quietly.

Beside those buttons is the seven-character build you are on. It is what makes
"it did that yesterday" answerable.

## Keys

**Keys** on the toolbar shows them all on a card. Or hold **?** — the card is
up while the key is down and gone when you let go, which is what you want in
the middle of dragging something. The button says the key, because a shortcut
nobody can find is a shortcut nobody has.

They are written here the way a Mac writes them. **On Windows and Linux, hold
Ctrl wherever this says ⌘** — Ctrl+Z, Ctrl+Shift+Z, Ctrl+C — and the card
spells them that way too, because it asks the machine it is running on rather
than the one this was written on.

- **⌘Z** undo, **⇧⌘Z** redo. A whole drag is one step.
- **⌫** delete what is selected — a node, several, or a wire.
- **esc** select nothing, which is also how you get the totals back to
  describing the whole canvas.
- **⌘F** find a node in this build. Type and the first match comes to you;
  Enter for the next one, ⇧Enter for the one before. It searches what a node
  is called and also what it makes or takes, so "sulfur" finds everything on
  that chain and not only the node with the word in its name.
- **⌘C** copy the selected nodes and **⌘V** paste them, into this build or
  another one. The wires between what you copied come with them.
- **⌘=** zoom in, **⌘−** out, **⌘0** back to life size.
- **arrow keys** nudge by a grid cell, eight with shift.
- **Change the recipe** on a node: a Rock Crusher that makes lime rather than
  sand, an Aquatuner on petroleum rather than water. It keeps the node where it
  is and every wire that still fits, and says how many did not.
- **space** and drag to pan, as above.

## Reusing work

- **Start from a build** opens one of four worked examples: oxygen for a crew,
  petroleum power, a Hatch ranch, a cooling loop. They are offered on an empty
  canvas, and live in the pipelines menu after that.
- **Use this build in another** turns the open build into a single node in the
  palette. Its edges become its ports and its totals become its figures, so a
  SPOM becomes "water and food in, carbon dioxide and spare power out". It is a
  snapshot: editing the original later does not change the copy in your plan.
- **Copy code** puts the build on the clipboard for somebody else's app;
  **copy summary** puts it there as text for a forum post or a note.
- **+ Recipe** writes down something the app does not know. A material it has
  never heard of can be invented on the spot — say whether it is a solid, a
  liquid or a gas, because that decides what carries it and whether it can be
  pumped — and it then behaves like any other material, with a supply and an
  output of its own.
- **Recipes you wrote** hands your own recipes to somebody else, all of them
  as one code. A figure the wiki never published — a Smoker's cycle time, say —
  is worth measuring once between everybody. Pasting somebody's pack merges it
  in; where an id collides theirs wins, and the app says how many of yours it
  replaced.
- **Export** writes the build out as a file you can keep. It lands in your
  downloads folder and the app says the full path; exporting the same build
  twice keeps both rather than overwriting yesterday's copy. The clipboard is
  for sending a build to somebody, this is for still having it next year.

## What this deliberately does not know

The app is most misleading where it is most confident, so:

- **Mixtures.** Every port carries one thing. A pipe of mixed gas cannot be
  drawn, which is why a filter here is a cost — a building and 120 W — rather
  than a separation.
- **Time.** Everything is a steady rate. A build that works on average may still
  starve at 3 a.m. when a geyser is dormant, and nothing here will tell you.
- **Space.** Floor area is a tile count, not a shape. Nothing knows whether it
  fits.
- **Spoilage, morale and germs.** A Dehydrator preserves food and this app sees
  only what that costs: 12 kg of plastic and a Duplicant's time for six packs.
  What it buys — food that never spoils — is a thing with no rate, so drying
  and restoring conserve calories exactly and the whole round trip shows up as
  a bill. Food quality is half the reason anyone cooks and is not modelled at
  all. Food quality is half the reason anyone cooks and
  is not modelled at all. Germs are deliberate too: they change no rate in the
  game — a Water Sieve passes them through at the same 5 kg/s either way — so a
  germ count here would be a number that never entered a calculation.
- **Heat, mostly.** Temperature is carried along wires and mixed by mass and
  specific heat, and a published figure always wins. A wire says how much heat
  it carries against a 25 °C base, which is what cooling it would cost. What
  nothing here models is where that heat actually goes: a pipe warming the room
  it runs through needs to know what the pipe is made of and what it runs past,
  and this model has no notion of space.
- **Rounding of your own.** Whole buildings are counted by rounding up, and
  what that leaves idle is reported. Any other rounding you do by hand is
  yours.

Anything the data is unsure of says so on the node itself, in amber, in the
words of what is doubtful — a rate nobody has published, a cycle time assumed
from similar buildings, a figure that is an average over a day. If a number
matters to you and it carries that warning, check it in game before building
around it.
