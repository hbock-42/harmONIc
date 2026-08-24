# Using the planner

The whole app is one idea: **draw what you are building, say how much of one
thing you have, and everything else follows.** Everything below is a detail
hanging off that.

Read it in order the first time. After that, the last section — what this
deliberately does not know — is the one worth remembering, because the app is
most misleading where it is most confident.

## Drawing a build

Pick something from the palette on the left and it appears on the canvas.
Buildings are grouped by what they are for; **My builds** at the top is where
your own saved builds go, and **Supply** and **Output** at the bottom are the
edges of a build — "water comes from somewhere else", "the oxygen goes to the
base".

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

**LEAST**, beside net power, heat or floor in the bottom bar, asks the same of
the build as a whole: the splits that draw the least, emit the least, or stand
on the least. The three rarely agree — a Rock Crusher draws a fifth of a Metal
Refinery's power and eats twice the ore for the same metal.

All of them write what they chose onto the wires as ordinary shares, so
afterwards it is a build like any other: you can see the splits, change them,
and undo the whole thing. And all of them say when there is no answer rather
than inventing one — nothing limits the build, or nothing has been asked of it,
or two amounts you set contradict each other.

## Wires

A wire is **pull** by default: the consumer decides, and the producer is sized to
cover it. **Push** is the other way — this line takes a fixed share of what the
producer makes, and the rest is somebody else's.

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

## Keys

**⌘** on the toolbar shows them all on a card. Or hold **?** — the card is up
while the key is down and gone when you let go, which is what you want in the
middle of dragging something.

- **⌘Z** undo, **⇧⌘Z** redo. A whole drag is one step.
- **⌫** delete what is selected — a node, several, or a wire.
- **esc** select nothing, which is also how you get the totals back to
  describing the whole canvas.
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
  only that it costs plastic. Food quality is half the reason anyone cooks and
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
