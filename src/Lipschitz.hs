module Lipschitz (lipschitz, evalLipschitz) where

import Concrete
import Interval
import Syntax

-- check that the shape belongs to the language where a bound of one holds
lipschitz :: SDF -> Either String Double
lipschitz e = validateSDF e >> Right 1

-- allow for how much the field could change between the centre and a corner
evalLipschitz :: SDF -> Box3 -> Either String Interval
evalLipschitz e b = do
  l <- lipschitz e
  c <- centre b
  r <- radius b
  v <- evalSDF e c
  margin <- finite (l*r)
  interval (v-margin) (v+margin)
