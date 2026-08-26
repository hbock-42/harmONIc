# Showing it to somebody who plays ONI

Ten minutes, three acts, nothing drawn in advance. Every figure below is what
the app actually says — they were read off it while this was written, so if one
of them is different on the day, the data changed and this file is wrong.

The audience knows the game and has never seen the app. So the first thing they
see should be a question they have asked themselves in front of their own base,
and the answer should be checkable against what they already believe. Trust for
the numbers they *cannot* check is bought with the ones they can.

This file is for a person driving. `E15` is the same script played by the app
itself, for the far larger number of people who open the site with nobody in
the room — and when that exists, the figures below stop being checked by hand:
the demo runs the real solver, and a test compares every number it narrates
with what the app says.

---

## Act one — "what will this geyser feed?" (four minutes)

Start on a blank canvas.

**1. Place the geyser.** Type `water` in the palette search. Point out, without
dwelling, that the list found the **Water Geyser** *and* the Electrolyzer, and
that the Electrolyzer's line says *takes water* — the list is searched by what
things carry, not only by what they are called. Click the Water Geyser.

**2. Follow the ports.** Click the geyser's **Water** dot. The menu lists
everything that could take water — say *"it only offers what you could actually
build; the pack switches at the top of the palette decide that"* — and pick
**Electrolyzer**. It is placed and wired in one move.

Click the Electrolyzer's **Oxygen** dot and pick **Duplicant**.

**3. Say the one number.** Select the geyser. In **I have this many**, type `1`.

Everything answers at once:

- **16 Duplicants.**
- The Electrolyzer says **1.80 ×**, build **2**, **90 % busy** — two placed, one
  of them idle a tenth of the time. This is the moment to say that the app never
  hides a fraction: rounding is shown as rounding.
- The bottom bar goes **red: −216 W**.

Let the red sit there for a second. Then:

**4. Make it pay for itself.** Click the Electrolyzer's **Hydrogen** dot, pick
**Hydrogen Generator**, then click the generator's **Power** dot and pick
**Power output**.

The bar turns green: **+1.40 kW** — 1 396.8 W, shown in kilowatts because the
app switches unit above a thousand. Same geyser, same sixteen dupes, and the
build now runs a base. That is a SPOM, discovered in two clicks rather than
looked up.

**5. The geyser's luck.** With the geyser selected, press **Worst**, then
**Best**, in *Assume active*:

| roll | dupes | spare power |
|---|---|---|
| 40 % | 10.7 | 931 W |
| 60 % (shipped) | 16.0 | 1.40 kW |
| 80 % | 21.3 | 1.86 kW |

Say what this is: a geyser rolls both its output *and* its active share when
the world is made, and the shipped rate is a lifetime average at a middling
roll. If somebody in the room knows their own geyser's figure, type it into the
second field — **what yours averages** — and the whole build moves to their
base. That usually gets the room.

**6. One wire.** Click the wire out of the geyser. It says what carries it, that
it **arrives at 95 °C**, what that costs to cool, and what a pipe would have to
be made of to survive it. Point at the last one: *"granite will not do."*

---

## Act two — "let it choose" (three minutes)

New tab. This is the part no other ONI calculator does.

**1. Draw the fork.** Place an **Iron Ore supply**, a **Metal Refinery** and a
**Rock Crusher (Metal)**. Wire the supply into both, and both into an **Iron
output**. Pin the supply at **10 kg/s**.

The app says **6.67 kg/s of metal** — because nobody said how the ore divides,
so it split it evenly.

**2. Ask for the best.** Select the **Iron output** node and press **Get as much
as possible**.

**10.00 kg/s.** Half as much again, from the same ore. The splits it chose are
written onto the wires as ordinary shares — you can see them, change them, and
undo the lot.

Say the honest version out loud: *the refinery is one-for-one and the crusher is
half, so of course everything should go to the refinery — but the app worked
that out from the recipes rather than being told, and it will do the same on a
build with thirty nodes where nobody could see it.*

**3. The other end.** This one has an order to it, and getting it wrong is the
one thing in the demo that will not work:

1. Select the **ore supply** and press **Clear**. The amount moves off the
   thing you are about to ask about.
2. Select the **Iron output** and set it to **5 kg/s**. That is the *asking*:
   what you want out of the build.
3. Select the ore supply again and press **Use as little as possible**.

**7.5 kg/s → 5 kg/s** of ore, for the same five kilograms of iron. It answers
the reverse question: what does it *cost* me to get what I asked for.

Say why the order matters, because somebody will try it the other way round: if
the only amount set is on the ore itself, the cheapest way to use no ore is to
make no metal, and that is a real answer to a question nobody meant. The app
says so rather than doing it.

**4. If somebody asks about power.** Press **LEAST** beside NET POWER in the
bottom bar. It picks the *crusher* — a fifth of a Metal Refinery's draw — and
uses twice the ore to do it. Three questions, three different answers, and the
app will not pretend one of them is *the* answer.

---

## Act three — the parts they will ask about (three minutes)

Pick whichever the room reacts to. All of them are one click.

- **Hold `?`** — the card of keys. Let go and it is gone.
- **Tidy** on a messy build.
- **A ranch**: open *Start from a build → Hatch ranch*. The bar carries an **AS
  BUILT** figure — the thirteenth Hatch cannot idle, so a real ranch eats more
  raw mineral than the ratio says. This is the thing spreadsheets get wrong.
- **Change the recipe**: select an Aquatuner and swap the coolant. Water needs
  1.5 machines per turbine; petroleum needs 3.56, because petroleum holds less
  than half the heat per kilogram. Super Coolant needs 0.74 — one machine
  outruns a turbine.
- **`+ Recipe`** — the wiki does not publish everything, so anything it is
  missing can be written down, used immediately, and handed to somebody else as
  one code.
- **The last section of the guide** (`?`): what the app deliberately does not
  know. Read one bullet aloud. It is the most persuasive page in the app.

---

## What to say when

**If somebody doubts a number:** every recipe carries where it came from, and
anything unverified says so in amber on the node itself. Show one.

**If somebody asks for a feature that is not there:** most of the missing ones
are missing because the figure is not published anywhere — that is a fact about
the wiki, not a to-do. `KANBAN.md` lists them with the reason.

**If somebody asks what it will not do:** mixtures, layout, time, morale. It is
in the guide, in writing, before they find out the hard way.

**Do not** open with the palette, the solver, or the file format. Open with the
geyser.
