# Solver design

## 1. What the user does

They draw a graph, then **pin exactly one thing**:

- "I have **3 Electrolyzers**" → `Pin.buildingCount`
- "I have **10 kg/s of Water**" → `Pin.portRate` on the water source's output port
- "I want **1000 g/s of Oxygen**" → `Pin.portRate` on the consumer/output port
- "I have **20 t of Algae** and want it to last **10 cycles**" → `Pin.stock` (converted to a rate)

Everything else must follow. That is a **linear** problem, so we solve it as one.

## 2. Variables

One variable per node: `x_n` = the number of *effective running units* of that node's process.

- a building node: number of buildings running at 100 % uptime (fractional is meaningful —
  `2.5` means "3 buildings, one of them idle half the time")
- a duplicant node: number of dupes
- a plant/critter node: number of plants/critters
- a raw source node: number of "supply units" (a source spec is defined as 1 g/s, so `x` is g/s)

Edge flows are **not** free variables — see §3. That is what keeps the system square and
lets a single pin determine the whole graph.

## 3. Edges: who decides the flow

An edge leaves an **output port** and enters an **input port**, carrying one item.
Each edge has a **mode**, and that mode says which end decides how much flows.

| mode | the flow is | use it for |
|---|---|---|
| `pull` *(default)* | what the **target needs** | planning: "20 dupes breathe 2 kg/s — how many Electrolyzers?" |
| `push` | a fixed fraction of what the **source makes** | a deliberate split, or auditing a base you already built |

Each edge also has a `share` ∈ [0, 1], read against whichever end drives it: a fraction of
the source port's *production* for `push`, of the target port's *demand* for `pull`.
Explicit shares are respected; unshared edges of the same group split `1 − Σ(explicit)`
equally. Either way the flow stays a linear function of **one** node count:

```
push:  f_e = share_e · outRate(src, srcPort) · x_src
pull:  f_e = share_e · inRate(tgt, tgtPort)  · x_tgt
```

On a single edge the two modes are the *same equation* — the difference only bites when a
port has several edges. Then `push` locks its consumers into a fixed ratio, while `pull`
lets each consumer size itself and makes the producer cover the sum. That is why `pull` is
the default: it is the direction you think in when planning a build, and it is what makes
one output feeding a dupe crew *and* an Oxylite Refinery come out right.

## 4. Equations

A port earns an equation only when the edges attached to it are driven from the **far** end:

- an **input** port with at least one `push` edge: what arrives must add up to its demand;
- an **output** port with at least one `pull` edge: what is taken must add up to its production.

```
input  (n,p):  Σ_{e → (n,p)} f_e  −  inRate(n, p)  · x_n  =  0
output (n,p):  Σ_{e ← (n,p)} f_e  −  outRate(n, p) · x_n  =  0
```

A port whose edges are all driven from its own side needs no equation, because it is already
an identity: `pull` edges into an input port sum to that port's demand by construction, and
`push` edges out of an output port each take a fraction of it. Whatever is left unclaimed is
**external supply** (on an input port) or **surplus** (on an output port), and is reported
rather than treated as an error.

> **The trade-off, and the way out.** An output port drained *only* by pull edges must
> deliver exactly what it makes — that equality is what sizes the producer. It also means
> "I have a geyser **and** twelve dupes" reads as a contradiction rather than as a question
> about the leftover. Marking the port as **vented** (`PipelineNode.ventedPorts`) drops its
> equation, so the port makes whatever it makes and the excess is reported as surplus. Use
> it when both ends are already pinned and you only want to know what is spare; leave it
> alone when you want the consumer to size the producer. The solver names the candidate
> ports whenever a system comes out inconsistent.

**Pin.** One row per pin:

| pin | row |
|---|---|
| `buildingCount(n, c)` | `x_n = c` |
| `portRate(n, p, r)` | `rate(n, p) · x_n = r` |
| `stock(n, p, mass, seconds)` | `rate(n, p) · x_n = mass / seconds` |

## 5. Solving

`A x = b`, dense Gauss–Jordan with partial pivoting and per-row normalisation
(graphs are small — hundreds of nodes at most; this is microseconds).

Outcomes:

| status | meaning | what the UI says |
|---|---|---|
| `solved` | rank = #nodes, consistent | show the numbers |
| `underdetermined` | free columns remain | "pin one of: *free nodes*" — the free variables are set to 0 and a partial solution is still returned |
| `inconsistent` | a `0 = k` row | "these pins contradict each other" |

Cycles (SPOM hydrogen return, petroleum boiler) need no special handling: they are simply
a matrix with entries above and below the diagonal.

When the system is inconsistent, the solver additionally lists every output port that is
drained only by pull edges — the usual culprit is a by-product with nowhere to vent, not a
genuine contradiction between pins.

## 6. After the solve

- **edge flows** `f_e = share_e · outRate · x_src`
- **port balances** per port: `required` vs `supplied` → `shortage` / `surplus`
- **item totals**: produced, consumed, net, per item
- **external inputs** (unfed input ports) and **external outputs** (unshipped output ports)
- **power** and **heat** are ordinary items (`power` in W, `heat` in kDTU/s), so the net power of
  the build falls out of the same balance sheet with no special case
- **integer rounding** (`E3-4`): ceil every count, recompute, report the resulting idle % per node

## 7. Invariants the tests enforce

1. For every solved graph, every *fed* input port has `shortage ≈ 0`.
2. Mass in = mass out + accumulation, per item, within ε.
3. Scaling a pin by `k` scales every `x_n` and `f_e` by `k` (the system is homogeneous apart
   from the pin row).
4. On a single-edge link, `push` and `pull` give identical answers.
5. Two consumers pulling from one producer size it to their **sum**, and each needs its own pin.
