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

## 3. Edges and shares

An edge leaves an **output port** and enters an **input port**, carrying one item.
Each edge has a `share` ∈ [0, 1]: the fraction of that output port's production it carries.

- explicit shares are respected;
- edges with no explicit share split `1 − Σ(explicit)` equally between them;
- if the shares of a port sum to less than 1, the remainder is **surplus** (vented / stored).

So the flow on edge `e` is a linear function of one variable:

```
f_e = share_e · outRate(src, srcPort) · x_src
```

> **v1 limitation, on purpose.** Equal splitting is a *modelling choice*, not an optimum.
> `E3-7` upgrades the solver to an LP that picks the shares itself (maximise a target output,
> minimise a raw input). Until then the UI exposes share sliders.

## 4. Equations

**Balance.** For every input port `p` of node `n` that has at least one incoming edge:

```
Σ_{e → (n,p)} share_e · outRate(src_e, port_e) · x_{src_e}  −  inRate(n, p) · x_n  =  0
```

An input port with **no** incoming edge produces no equation: it is an *external supply*
(a raw resource you are expected to provide) and is reported as such.

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
