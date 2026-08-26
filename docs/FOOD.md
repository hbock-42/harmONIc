# A cooked dish is a material

Written before the code, the way `SOLVER.md` and `CHOOSING-SHARES.md` were.
`E4-53` says *"a Gas Range takes cooked food and this app cannot say so"*, and
the first job is to be precise about why, because "add the recipes" is not a
description of anything.

## What the app cannot say today

Every one of the 34 recipes that cooks something outputs the same thing:
**calories**. A Frost Bun is 24 kcal/s and a Barbeque is 80 kcal/s, and once
they are made they are indistinguishable. Two things consume calories — a
Duplicant, and the Dehydrator.

That is a good model of *feeding people*. You can ask "how many Duplicants does
this base feed" and get an answer that does not care which dish.

It cannot model *cooking*, and the Gas Range is almost entirely cooking:

| dish | takes |
|---|---|
| Stuffed Berry | 2 kg Gristle Berry, 2 kg Pincha Peppernut |
| Mushroom Wrap | 1 kg Fried Mushroom, 4 kg Lettuce |
| Surf'n'Turf | 1 kg Barbeque, 1 kg Cooked Seafood |
| Mushroom Quiche | 1 kg Omelette, 1 kg Lettuce, 1 kg Fried Mushroom |
| Frost Burger | 1 kg Frost Bun, 1 kg Lettuce, 1 kg Barbeque |

Gristle Berry, Fried Mushroom, Barbeque, Cooked Seafood, Omelette and Frost Bun
are all Electric Grill dishes. In this app they are calories, so none of these
five recipes can be drawn. Five of the Gas Range's nine.

## What it would take

A dish becomes an ordinary item, and the grill makes kilograms of it rather
than kilocalories. Then a Gas Range takes 2 kg of Gristle Berry the same way a
Kiln takes 200 kg of wood, and nothing about the solver changes.

The question that answers is: **who turns a dish into calories?** Nobody eats
kilograms. The answer that fits what this app already does is a *generated*
process, the way every item already gets a supply, an output, a pump, a filter
and an Aquatuner:

```
Eat Gristle Berry:  1 kg/s in  ->  2000 kcal/s out
```

One per food item, generated from a `kcalPerKg` on the item itself, and the
Duplicant goes on eating calories exactly as now. A build that only wants to
feed people wires the grill straight to an eating node and sees the same
figures it sees today. A build that wants to cook wires the grill into the Gas
Range instead, and the calories appear at the end of the chain rather than in
the middle of it.

## What it costs

- **Every food recipe changes**, all 34 of them: the output stops being
  `calories` and becomes the dish. Mechanical, and the mass-balance audit will
  have something to say about each one, which is the point of it.
- **Every food item needs its kcal per kg**, which the wiki publishes for all
  of them — that is the number every recipe table is already quoting.
- **The Duplicant does not change.** Nor does the Dehydrator, which takes
  6000 kcal "of any food prepared with the Gas Range" and is honestly modelled
  as calories.
- **Two nodes where there was one**, for anybody who only wants to be fed. That
  is the real cost, and it is why this is written down rather than done: it
  makes the simple case slightly worse to make the impossible case possible.

## The decision

Do it, and generate the eating nodes rather than writing them. The Gas Range is
not an edge case — it is the second cooking building anybody builds, and five
of its nine recipes are unreachable without this.

What would change my mind: if the eating node reads as clutter to somebody
watching the demo, the alternative is to let a Duplicant's calories port accept
any food item directly and convert on the way in. That is a smaller graph and a
larger change to the solver, which is the wrong way round for a model whose
whole argument is that one equation per port explains everything.
