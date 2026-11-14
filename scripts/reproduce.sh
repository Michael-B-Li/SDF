#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
out=${1:-results}
mkdir -p "$out"
cabal_cmd() {
  if [ -n "${SDF_CABAL_CONFIG:-}" ]; then
    cabal --config-file="$SDF_CABAL_CONFIG" "$@"
  else
    cabal "$@"
  fi
}
cabal_cmd build all > "$out/build.txt" 2>&1
cabal_cmd test --test-show-details=direct > "$out/tests.txt" 2>&1
binary=$(cabal_cmd list-bin exe:sdf-analyse)
"$binary" bench "$out/benchmarks.csv" 4 7
"$binary" slice "$out/slice.ppm" 128
{
  printf '%s\n' 'Double approximation: no certified floating-point enclosures.'
  printf '%s\n' 'Depths 0..4; 7 trials; QuickCheck seed 20261114; -O2.'
  ghc --version
  cabal --version
  uname -sm
  if command -v sw_vers >/dev/null 2>&1; then sw_vers; fi
  printf '%s\n' 'Source checksums (POSIX cksum):'
  cksum src/*.hs app/*.hs benchmarks/*.hs test/*.hs cabal.project cabal.project.freeze
} > "$out/environment.txt"
