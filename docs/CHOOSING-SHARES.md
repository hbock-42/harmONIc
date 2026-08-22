# Letting the solver choose

A decision written before the code, the way `SOLVER.md` was. `E3-7` has read
*"simplex / LP upgrade — let the solver choose the shares to maximise a target
output or minimise a raw input"* since the solver was designed, and the first
job is to say precisely what that means here, because "add an LP" is not a
description of anything.

## What the app cannot answer today

Draw a Metal Refinery fed by an ore supply, with its hot water going to a Steam
Turbine and to a cooling loop. Two edges leave one port. Somebody has to say
how the water divides, and today that somebody is you: set a share, or accept
an even split, and the app reports what follows.

The question people actually arrive with is the other way round:

- *"I have 10 kg/s of water. What is the most oxygen I can get out of it?"*
- *"I want 2 kg/s of oxygen. What is the least algae that does it?"*
- *"Between the turbine and the loop, what split wastes the least heat?"*

Every one of those asks the app to **choose** a number it currently makes you
supply. That is the whole of `E3-7`.

## Why it is not a small change

The current formulation is square on purpose (`SOLVER.md` §2): one variable per
node, and edge flows are *not* free — each is a fixed multiple of one node's
count.

```
push:  f_e = share_e · outRate(src, srcPort) · x_src
pull:  f_e = share_e · inRate(tgt, tgtPort)  · x_tgt
```

That is what lets a single pin determine everything, and it is why the solver
is a plain elimination that runs in 14 ms on 500 nodes.

Make `share_e` a variable and that line stops being linear: it becomes
`share_e · x_src`, a product of two unknowns. A simplex cannot take it. So
"make the shares variables" is not the change — **making the flows variables**
is:

```
variables:  x_n ≥ 0  for every node,  f_e ≥ 0  for every edge
port balance (input):   Σ_{e → (n,p)}  f_e  =  inRate(n, p)  · x_n
port balance (output):  Σ_{e ← (n,p)}  f_e  ≤  outRate(n, p) · x_n
pins:                   as today, one equality row each
objective:              maximise (or minimise) one linear expression
```

The shares fall out afterwards as `f_e ÷ (what its port carries)`, which is the
number to show, but no longer the number to solve for. Note the output rows
become **inequalities**: what leaves a port may be less than what it makes, and
what is left is the surplus the app already reports. That inequality is exactly
the freedom an optimiser needs, and exactly what an equality-only solver cannot
express.

## What this costs

- **A simplex.** Two-phase, because the constraint set has equalities and no
  obvious feasible starting point; Bland's rule at least as a fallback, because
  a degenerate network — and every graph with a cycle is degenerate — can cycle
  for ever under the usual pivot choice. Perhaps 300 lines, and testable
  against problems whose answers can be worked out on paper.
- **Roughly three times the variables.** A 500-node build has around 700 edges,
  so 1 200 columns rather than 500. Simplex is not cubic in the way the old
  Gauss–Jordan was, but it is not free either, and the perf test's promise —
  50 ms — is a promise about the *existing* solve, which must keep it.
- **A second set of answers.** Two solvers that disagree is worse than one that
  cannot optimise. Whatever ships has to agree with the current solver on every
  build that has no freedom in it, and that agreement is a test, not a hope.

## The decision

Do it, in this order, and never with the LP as the only path.

1. **`E3-7a` — the simplex itself.** A general two-phase implementation with
   textbook tests, and no dependency on anything in this app. It is much easier
   to be sure of a solver against problems with known answers than against a
   build whose right answer is the thing in question.
2. **`E3-7c` — one question, end to end.** *"Maximise this output"* on a build
   that has a choice in it. **Done.** It turned out to need one thing this
   plan did not mention: the answer has to be written back as *shares*, or the
   two solvers would both be on screen at once. `withShares` does that — the
   simplex chooses, the choice becomes the same numbers somebody could have
   typed, and every figure the app shows still comes from the elimination. The
   agreement test is per template: optimise, write the shares back, solve, and
   the counts must match what the ordinary solver said to six places.
3. **`E3-7d` — the rest of the questions.** Minimise a raw input, then the
   objectives that are not a single port: least heat, least power, least floor.

Nothing here changes the default path. A build with every share set has no
freedom, the LP would return exactly what the elimination returns, and running
it would be a slower way to get the same numbers. The optimiser is a question
you ask, not a solver you replace — which also means step 1 landing without
step 2 would be dead code, and it is written down here so that it does not sit
that way for long.

## What it will not do

- **Integers.** "Choose the shares" is a continuous question; "choose the
  number of buildings" is not, and branch-and-bound is a different project. The
  rounding this app already does — ceil, then report the idle percentage — is
  the honest answer, and it stays.
- **Choose your pins for you.** The pin is what makes a build *yours*: it is
  the thing you have. An optimiser that invented one would be answering a
  question nobody asked.
- **Argue with a share you set.** An explicit share is a decision, and the
  optimiser optimises around it rather than over it. Only the shares nobody
  has set are free.
