# Comparing Interval and Lipschitz Bounds for Signed Distance Fields

## 1. Aim

This project compares two ways of estimating the values of a signed distance
field (SDF) over a 3D region. The aim is to find out which method gives tighter
bounds and how much time each method takes.

An SDF represents a shape using a function. Negative values mean inside,
positive values mean outside, and zero marks the surface. If we can show that
all values in a region are above or below zero, we can rule out a surface there.
This could help avoid unnecessary work when processing a scene.

The project is implemented in Haskell. It compares **interval analysis**, which
works through the structure of a shape expression, with **Lipschitz bounds**,
which use the value at the centre of a region and a limit on how quickly the
function can change.

## 2. Representing shapes

The language supports spheres, axis-aligned boxes, translations, and three
constructive solid geometry (CSG) operations: union, intersection, and difference.
These combine two shapes into a more complex one.

For a point $p$, a sphere with radius $r$ has the value

$$
f(p)=\|p\|_2-r.
$$

Here, $\|p\|_2$ is the distance from $p$ to the origin. For a box, $h$ gives
half its width, height, and depth. Setting $q=|p|-h$, its field is

$$
f(p)=\|\max(q,0)\|_2+\min(\max(q_x,q_y,q_z),0).
$$

Absolute value and the maximum with zero are applied to each coordinate.
Translation by $t$ evaluates the original shape at $p-t$. The CSG operations
combine the values of two shapes, $a$ and $b$:

$$
\begin{aligned}
\text{union:}\quad &\min(f_a(p),f_b(p)),\\
\text{intersection:}\quad &\max(f_a(p),f_b(p)),\\
\text{difference:}\quad &\max(f_a(p),-f_b(p)).
\end{aligned}
$$

These combined fields are useful for describing shapes, but their values are
not always exact distances to the resulting surface. Dimensions must be finite
and nonnegative. Zero-sized shapes are allowed.

## 3. Interval analysis

Instead of evaluating one point, interval analysis evaluates a whole region.
Each coordinate is represented by a range, such as $x\in[1,3]$. Arithmetic then
works on ranges rather than individual numbers. For example,

$$
[1,3]+[2,4]=[3,7].
$$

More generally, addition and negation use these rules:

$$
[l,u]+[a,b]=[l+a,u+b],\qquad -[l,u]=[-u,-l].
$$

Minimum and maximum operate on the lower and upper endpoints separately.
Absolute value needs extra care when a range crosses zero: for example,
$|[-2,3]|=[0,3]$, so squaring that range gives $[0,9]$.
Square roots are only taken for ranges with a nonnegative lower endpoint.

The evaluator applies these rules throughout the shape expression. A translation
shifts the input region, while a CSG operation combines the ranges returned by
its two children.

### Why the bounds are sound

A bound is sound if it contains every possible field value in the region.
Each interval operation includes every result of the corresponding ordinary
operation. The sphere and box formulas are built from these operations, so
their bounds are sound. Translation evaluates a shifted region. For CSG, if the
two child bounds are sound, applying minimum, maximum, or negation gives a sound
parent bound. This is a proof by structural induction over the expression.

If the final range $[l,u]$ has $u<0$ or $l>0$, it excludes zero. The program calls
this `DefinitelyEmpty`, meaning no zero-level surface is present. The region
could still be entirely inside a solid. If the range includes zero, the result
is `PossiblySurface`: a surface might be present, but the bound cannot decide.

This argument assumes exact arithmetic. The implementation uses `Double`, so
rounding errors mean its bounds are not certified guarantees.

## 4. Lipschitz bounds

A function is 1-Lipschitz if its value changes by no more than the distance
between two points:

$$
|f(p)-f(q)|\le\|p-q\|_2.
$$

Spheres and boxes satisfy this condition. Translation, negation, minimum, and
maximum preserve it, so it also holds for every expression in this language.

Let $c$ be the centre of a region and $\rho$ the distance from its centre to a
corner. Every point in the region is at most $\rho$ from $c$, giving the bound

$$
[f(c)-\rho,\ f(c)+\rho].
$$

For this particular language, interval analysis gives bounds contained within
the Lipschitz bounds in exact arithmetic. For a sphere or box, the interval
method finds the exact minimum and maximum over an axis-aligned region.
Translation preserves this relationship, and the CSG operations preserve
containment as expressions are combined.

This does not mean interval analysis is exact for every combined shape. It can
lose information about relationships between repeated expressions. For example,
`Difference e e` computes $|f_e|$, but its interval bound can still include
negative values. Even so, intersecting the interval and Lipschitz bounds would
not tighten the interval result in exact arithmetic, so a combined method is
not included.

## 5. Testing and experiments

The tests use QuickCheck, with 14 groups of 1,000 random cases and two fixed
suites. They check whether bounds contain values at sampled points, as well as
arithmetic, shape operations, subdivision, and invalid inputs. The random seed
is fixed at `20261114` so the tests can be repeated. These checks help find bugs,
but do not prove floating-point soundness.

The benchmark uses seven scenes over $[-2.5,2.5]^3$. Each subdivision splits a
cell into eight smaller cells. Both methods use the same cells at depths 0–4,
with 4,096 cells at depth four. Cells are not skipped after being classified.

Each method is warmed up and timed seven times per scene and depth. The table
below reports median CPU time. Timing includes evaluation and classification,
but excludes creating the cells and writing the output files. The recorded run
used GHC 9.4.8, Cabal 3.10.3.0, `-O2`, and an ARM64 Mac running macOS 14.3.1.

## 6. Results

These results are for depth four. **I** means interval analysis and **L** means
Lipschitz bounds. Width is the average upper bound minus lower bound; smaller
is more precise. Empty is the number of cells classified as having no zero-level
surface. Times are in milliseconds.

| Scene | I width | I empty | I ms | L width | L empty | L ms |
|---|---:|---:|---:|---:|---:|---:|
| sphere | 0.4835 | 3872 | 0.510 | 0.5413 | 3872 | 0.608 |
| box | 0.4109 | 3952 | 1.059 | 0.5413 | 3936 | 0.720 |
| union | 0.4357 | 3812 | 2.077 | 0.5413 | 3784 | 1.049 |
| intersection | 0.4548 | 4048 | 1.931 | 0.5413 | 4012 | 0.982 |
| difference | 0.4145 | 3976 | 1.658 | 0.5413 | 3952 | 0.872 |
| nested | 0.4362 | 3795 | 3.166 | 0.5413 | 3767 | 1.390 |
| translated | 0.4426 | 3788 | 2.721 | 0.5413 | 3754 | 1.251 |

Interval analysis gives narrower average bounds in every scene shown. However,
this does not always help classify more cells: both methods give the same empty
count for the sphere. For the nested scene, interval analysis rules out 28 more
cells, but takes more than twice as long. Lipschitz bounds are faster in every
scene shown except the sphere.

Smaller cells improve precision for both methods, but each extra subdivision
level multiplies the number of cells by eight. The useful trade-off is therefore
between tighter bounds, classification results, and total processing time.

To repeat the experiment, run this from the project root:

```sh
sh scripts/reproduce.sh
```

This creates the benchmark CSV, build/test logs, and a PPM slice image in
`results/`. The image compares both methods at $z=0$. Generated files are
excluded from the repository, and timings will vary between runs and machines.

## 7. Limitations and possible improvements

The main limitation is floating-point rounding. The program checks invalid
inputs and detected overflow, but ordinary `Double` arithmetic can still produce
bounds that miss a true value. Outward rounding, where each endpoint is rounded
away from the interval's interior, would be an important next step towards
certified bounds.

The experiments also cover only seven small scenes on one machine. They show
how these implementations compare, rather than which method is always faster.
Further work could add more complex scenes and adaptive subdivision, where only
uncertain cells are split. Extending the language would also require checking
whether the soundness and precision arguments still hold.
