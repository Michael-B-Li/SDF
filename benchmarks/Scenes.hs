module Scenes (scenes, benchmarkRegion) where

import Interval
import Syntax

-- keep same shapes across the benchmarks and slice image
scenes :: Either String [(String,SDF)]
scenes = do
  h <- vec3 1 0.75 0.5
  left <- vec3 (-0.7) 0 0
  right <- vec3 0.7 0 0
  up <- vec3 0 0.8 0.3
  let sphere = Sphere 1
      box = Box h
      a = Translate left sphere
      b = Translate right box
      c = Translate up (Sphere 0.6)
  pure [("sphere",sphere), ("box",box), ("union",Union a b),
        ("intersection",Intersection a b), ("difference",Difference box a),
        ("nested",Difference (Union a b) (Intersection c sphere)),
        ("translated",Union (Union a b) c)]

-- keep the comparison area fixed for every scene
benchmarkRegion :: Either String Box3
benchmarkRegion = do
  lo <- vec3 (-2.5) (-2.5) (-2.5)
  hi <- vec3 2.5 2.5 2.5
  box3 lo hi
