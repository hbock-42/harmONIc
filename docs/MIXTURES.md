# Mixtures, and why not yet

`E11-8` has read *"a port carries one thing, so a pipe of mixed gas cannot be
drawn; wanted by filters, by pressure, and by anything that sorts"* since the
model was written. This is the decision, in the same spirit as
`CHOOSING-SHARES.md`: what it would cost, what it would buy, and what to do
instead — because "support mixtures" describes an ambition rather than a change.

Unlike that one, this decision is **no**. The reasoning is worth keeping
anyway, and so is the experiment that changed my mind halfway through writing
it.

## What a mixture would have to be

Every flow here is one item at one rate, which is what makes a port balance a
single equation. A mixture is a *set* of items in proportions nobody knows until
the build is solved — so it cannot be an item, because the item's identity would
depend on the answer and the answer would depend on the identity. That
circularity rules out the tempting cheap version: a generated
`oxygen+carbon_dioxide` item per combination, of which there are 2ⁿ.

The honest version is that an **edge carries a vector**: one flow variable per
(edge, item) rather than per edge. Everything else follows — port balances per
item, conduit capacity on the sum, a filter with a remainder port — and so does
the cost:

- the solver's variables go from *nodes* to *nodes + edges × items*, which is
  where a 500-node build stops being 14 ms;
- every port equation multiplies by the items that could be in that pipe;
- and the app has to answer, for every mixed pipe, **what is in it** — which is
  a question about your base's layout rather than about the build's ratios.

## What it would buy, item by item

The row's summary is generous, and going through it one line at a time is what
settled this.

**A filter that separates.** Today a filter is a toll booth: a building, 120 W,
and a note saying the gas it does not want goes on down the pipe, which this
does not track. But the ratios are unaffected — you draw the two streams you
wanted anyway — so what a mixture buys here is bookkeeping tidiness and not one
number that changes. That is the weakest kind of reason to grow a model.

**Pressure, sorting, atmo sensors.** All of it is about layout. `USING.md` says
this app has no notion of space, and means it. A mixed pipe exists because two
gases were in one room; a room is a shape.

**One pipe instead of two.** This looked like the real one: two gases going the
same way share a pipe in game if the total fits, and this app counts a pipe for
each. It is the only case in the family that would change a number the app
prints today, and it does not need a mixture to fix — two flows between the same
pair of nodes, of the same kind, adding up to less than a pipe, is arithmetic on
figures the solver already produces.

So I built it, and then measured how often it can arise:

```
Oxygen for the crew: 6 edges, 0 parallel pairs
Petroleum power:     6 edges, 0 parallel pairs
Hatch ranch:         6 edges, 0 parallel pairs
Cooling loop:        6 edges, 0 parallel pairs
```

Never. And the reason is structural rather than a small sample: an output node
carries one item, so two gases cannot arrive at the same one — the validator
refuses it, correctly. Two lines share a *pair of nodes* only when both ends are
multi-port buildings, which is rare, and they share a *pipe* only when they also
share a route, which is layout again.

A hundred lines that fire on no build anybody has drawn is worse than nothing,
so they went in the bin. The experiment is the useful part: the case that
justified the feature turned out not to occur.

## The decision

**Not now, and not the shared-pipe consolation prize either.** What would have
to be true first:

- a reason that changes a **number** rather than the bookkeeping — the filter
  does not, and the shared pipe does not occur;
- a solver that holds the extra variables inside `E3-9`'s 50 ms;
- and some notion of place, or at least of "these things share an atmosphere",
  without which a mixed pipe cannot be said to exist at all.

Until then the app keeps saying plainly, in `USING.md`, that every port carries
one thing and that a filter here is a cost rather than a separation. Being clear
about a limit is worth more than a half-built way around it — which is the same
conclusion `E11-5` reached about conduit heat, from the same direction.
