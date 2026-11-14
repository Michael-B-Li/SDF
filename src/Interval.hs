module Interval
  ( Interval, interval, point, lower, upper, width, contains
  , addI, subI, negI, minI, maxI, mulI, squareI, sqrtI, absI, normI
  , Box3, box3, axes, fromAxes, containsPoint, centre, radius, splitBox
  ) where

import Syntax

data Interval = I Double Double deriving (Show, Eq)

-- keep invalid endpoints out of the interval operations below
interval :: Double -> Double -> Either String Interval
interval l u = do
  _ <- finite l
  _ <- finite u
  if l <= u then Right (I l u) else Left "Reversed interval endpoints"

point :: Double -> Either String Interval
point x = interval x x

lower, upper :: Interval -> Double
lower (I l _) = l
upper (I _ u) = u

width :: Interval -> Either String Double
width (I l u) = finite (u-l)

contains :: Interval -> Double -> Bool
contains (I l u) x = l <= x && x <= u

-- work out bounds from the endpoints using ordinary floating point arithmetic
addI, subI, mulI :: Interval -> Interval -> Either String Interval
addI (I l u) (I a b) = interval (l+a) (u+b)
subI a b = addI a (negI b)
mulI (I l u) (I a b) = do
  xs <- traverse finite [l*a,l*b,u*a,u*b]
  case xs of
    x:rest -> interval (foldr min x rest) (foldr max x rest)
    [] -> Left "Internal error: no endpoint products"

negI, absI :: Interval -> Interval
negI (I l u) = I (-u) (-l)
-- include zero when the range crosses from negative to positive
absI (I l u)
  | l >= 0 = I l u
  | u <= 0 = I (-u) (-l)
  | otherwise = I 0 (max (-l) u)

minI, maxI :: Interval -> Interval -> Interval
minI (I l u) (I a b) = I (min l a) (min u b)
maxI (I l u) (I a b) = I (max l a) (max u b)

squareI, sqrtI :: Interval -> Either String Interval
squareI a = let I l u = absI a in interval (l*l) (u*u)
sqrtI (I l u)
  | l < 0 = Left "Square root requires a nonnegative interval"
  | otherwise = interval (sqrt l) (sqrt u)

-- use the nearest and farthest coordinates to bound distance from the origin
normI :: Interval -> Interval -> Interval -> Either String Interval
normI x y z = do
  let I a b = absI x; I c d = absI y; I e f = absI z
  lo <- norm3 a c e
  hi <- norm3 b d f
  interval lo hi

data Box3 = B Interval Interval Interval deriving (Show, Eq)

fromAxes :: Interval -> Interval -> Interval -> Box3
fromAxes = B

axes :: Box3 -> (Interval, Interval, Interval)
axes (B x y z) = (x,y,z)

box3 :: Vec3 -> Vec3 -> Either String Box3
box3 lo hi = let (x,y,z) = components lo; (a,b,c) = components hi
             in B <$> interval x a <*> interval y b <*> interval z c

containsPoint :: Box3 -> Vec3 -> Bool
containsPoint (B x y z) p = let (a,b,c) = components p
                          in contains x a && contains y b && contains z c

-- avoid overflow where possible and keep rounding from moving the midpoint outside
midpoint :: Interval -> Double
midpoint (I l u) = max l (min u m)
  where m = if l < 0 && u > 0 then l/2+u/2 else l+(u-l)/2

centre :: Box3 -> Either String Vec3
centre (B x y z) = vec3 (midpoint x) (midpoint y) (midpoint z)

-- reach the farther endpoint on each axis in case the midpoint rounded off centre
radius :: Box3 -> Either String Double
radius (B x y z) = do
  let extent i = finite (max (midpoint i-lower i) (upper i-midpoint i))
  a <- extent x
  b <- extent y
  c <- extent z
  norm3 a b c

-- give both halves the midpoint so there are no gaps between cells
splitBox :: Box3 -> [Box3]
splitBox (B x y z) = [B a b c | a <- split x, b <- split y, c <- split z]
  where split i@(I l u) = let m = midpoint i in [I l m,I m u]
