module Concrete (evalSDF) where

import Syntax

-- check the shape first so an invalid branch cannot slip through
evalSDF :: SDF -> Vec3 -> Either String Double
evalSDF e p = validateSDF e >> go e p
  where
    go (Sphere r) v = do
      let (x,y,z) = components v
      n <- norm3 x y z
      finite (n-r)
    -- measure distance outside the box and keep values negative inside
    go (Box h) v = do
      let (x,y,z) = components v
          (a,b,c) = components h
          qx = abs x-a; qy = abs y-b; qz = abs z-c
      n <- norm3 (max qx 0) (max qy 0) (max qz 0)
      finite (n + min (max qx (max qy qz)) 0)
    go (Translate t a) v = subVec v t >>= go a
    go (Union a b) v = min <$> go a v <*> go b v
    go (Intersection a b) v = max <$> go a v <*> go b v
    go (Difference a b) v = max <$> go a v <*> (negate <$> go b v)
