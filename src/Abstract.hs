module Abstract (evalAbstract) where

import Interval
import Syntax

-- check the whole shape before working out a range for the region
evalAbstract :: SDF -> Box3 -> Either String Interval
evalAbstract e region = validateSDF e >> go e region
  where
    go (Sphere r) b = do
      let (x,y,z) = axes b
      n <- normI x y z
      point r >>= subI n
    -- combine the outside distance with the part of the box formula for points inside
    go (Box h) b = do
      let (x,y,z) = axes b; (a,c,d) = components h
          offset i v = point v >>= subI (absI i)
      qx <- offset x a
      qy <- offset y c
      qz <- offset z d
      zero <- point 0
      outside <- normI (maxI qx zero) (maxI qy zero) (maxI qz zero)
      addI outside (minI (maxI qx (maxI qy qz)) zero)
    -- move the region back so the child can use its original coordinates
    go (Translate t a) b = do
      let (x,y,z) = axes b; (tx,ty,tz) = components t
          shift i v = point v >>= subI i
      moved <- fromAxes <$> shift x tx <*> shift y ty <*> shift z tz
      go a moved
    go (Union a b) r = minI <$> go a r <*> go b r
    go (Intersection a b) r = maxI <$> go a r <*> go b r
    go (Difference a b) r = maxI <$> go a r <*> (negI <$> go b r)
