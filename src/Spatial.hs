module Spatial (Classification(..), classify, uniformRegions) where

import Interval

data Classification = DefinitelyEmpty | PossiblySurface deriving (Show, Eq)

-- look for ranges that rule out a surface, including cells entirely inside a solid
-- rounding means this is only an approximate decision
classify :: Interval -> Classification
classify i
  | upper i < 0 || lower i > 0 = DefinitelyEmpty
  | otherwise = PossiblySurface

-- split every cell equally so both methods get the same regions to compare
uniformRegions :: Int -> Box3 -> Either String [Box3]
uniformRegions depth b
  | depth < 0 = Left "Subdivision depth must be nonnegative"
  | otherwise = Right (go depth b)
  where
    go 0 r = [r]
    go n r = concatMap (go (n-1)) (splitBox r)
