# SDF Abstract Interpreter

A Haskell project comparing interval analysis and Lipschitz bounds for
procedural signed distance fields. The aim is to study the trade-off between
precision and runtime when identifying regions that contain no surface.

The shape language supports spheres, axis-aligned boxes, translations, and
constructive solid geometry operations: union, intersection, and difference.

## Build and run

Tested with GHC 9.4.8 and Cabal 3.10.3.0. If using a different GHC version,
move `cabal.project.freeze` aside so Cabal can resolve the dependencies again.

```sh
cabal build all
cabal test --test-show-details=direct
cabal run sdf-analyse
```

To run the full experiment:

```sh
sh scripts/reproduce.sh
```

This saves the benchmark results, a slice image in PPM format, and build/test logs
in `results/`.

The [report](docs/report.md) describes the methods, their mathematical basis,
and the experimental results. The soundness argument assumes exact arithmetic;
the implementation uses `Double`, so rounding errors can affect whether the
bounds contain every field value in a region.
