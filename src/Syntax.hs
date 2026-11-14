module Syntax
  ( Vec3, vec3, components, subVec, norm3, finite
  , SDF(..), validateSDF
  ) where

data Vec3 = Vec3 Double Double Double deriving (Show, Eq)

finite :: Double -> Either String Double
finite x
  | isNaN x || isInfinite x = Left "Non-finite input or numerical overflow"
  | otherwise = Right x

-- check coordinates here so the rest of the code can assume they are finite
vec3 :: Double -> Double -> Double -> Either String Vec3
vec3 x y z = Vec3 <$> finite x <*> finite y <*> finite z

components :: Vec3 -> (Double, Double, Double)
components (Vec3 x y z) = (x, y, z)

subVec :: Vec3 -> Vec3 -> Either String Vec3
subVec (Vec3 x y z) (Vec3 a b c) = vec3 (x-a) (y-b) (z-c)

-- scale before squaring to handle very large and very small coordinates
norm3 :: Double -> Double -> Double -> Either String Double
norm3 x y z = do
  mapM_ finite [x,y,z]
  finite (if m == 0 then 0 else
    m * sqrt ((x/m)^two + (y/m)^two + (z/m)^two))
  where
    m = max (abs x) (max (abs y) (abs z))
    two = 2 :: Int

data SDF
  = Sphere Double
  | Box Vec3
  | Translate Vec3 SDF
  | Union SDF SDF
  | Intersection SDF SDF
  | Difference SDF SDF
  deriving (Show, Eq)

-- walk every branch so invalid dimensions are caught before evaluation
validateSDF :: SDF -> Either String ()
validateSDF (Sphere r) = nonnegative r
validateSDF (Box h) = let (x,y,z) = components h
                     in mapM_ nonnegative [x,y,z]
validateSDF (Translate _ e) = validateSDF e
validateSDF (Union a b) = validateSDF a >> validateSDF b
validateSDF (Intersection a b) = validateSDF a >> validateSDF b
validateSDF (Difference a b) = validateSDF a >> validateSDF b

nonnegative :: Double -> Either String ()
nonnegative x = do
  _ <- finite x
  if x >= 0 then Right () else Left "Primitive dimensions must be nonnegative"
