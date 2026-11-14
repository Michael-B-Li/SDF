module Main (main) where

import Abstract
import Concrete
import Control.Monad (unless)
import Data.Either (isLeft)
import Interval
import Lipschitz
import Spatial
import Syntax
import System.Exit (exitFailure)
import Test.QuickCheck hiding (classify, scale)
import Test.QuickCheck.Random (mkQCGen)

type Trial = Either String (SDF, Box3, Vec3)

genVec :: Double -> Gen (Either String Vec3)
genVec k = vec3 <$> choose (-k,k) <*> choose (-k,k) <*> choose (-k,k)

-- mix simple shapes with nested operations without letting expressions grow too large
genExpr :: Int -> Gen (Either String SDF)
genExpr n
  | n <= 0 = primitive
  | otherwise = frequency
      [(3,primitive), (2,translated), (3,binary)]
  where
    primitive = oneof
      [Right . Sphere <$> choose (0,3),
       fmap Box <$> (vec3 <$> choose (0,3) <*> choose (0,3) <*> choose (0,3))]
    translated = do
      t <- genVec 3
      e <- genExpr (n-1)
      pure (Translate <$> t <*> e)
    binary = do
      op <- elements [Union,Intersection,Difference]
      a <- genExpr (n `div` 2)
      b <- genExpr (n `div` 2)
      pure (op <$> a <*> b)

-- include flat regions and boundary points alongside ordinary random cases
genTrial :: Gen Trial
genTrial = do
  e <- genExpr 4
  lo <- genVec 4
  sizes <- vectorOf 3 (frequency [(1,pure 0),(4,choose (0,4))])
  ts <- vectorOf 3 (frequency [(1,pure 0),(1,pure 1),(4,choose (0,1))])
  pure $ do
    s <- e
    v <- lo
    let (x,y,z) = components v
    case (sizes,ts) of
      ([a,b,c],[t,u,w]) -> do
        hi <- vec3 (x+a) (y+b) (z+c)
        region <- box3 v hi
        p <- vec3 (x+t*a) (y+u*b) (z+w*c)
        Right (s,region,p)
      _ -> Left "Generator vector length mismatch"

checked :: Either String a -> (a -> Property) -> Property
checked (Left err) _ = counterexample err False
checked (Right x) f = f x

-- allow small rounding differences in tests without treating them as a soundness guarantee
near :: Double -> Double -> Bool
near a b = abs (a-b) <= 1e-10 * max 1 (max (abs a) (abs b))

encloses :: Interval -> Double -> Bool
encloses i x = (lower i <= x || near (lower i) x)
            && (x <= upper i || near (upper i) x)

-- try smaller expressions when a test fails to make the cause easier to spot
onTrial :: ((SDF,Box3,Vec3) -> Property) -> Property
onTrial f = forAllShrink genTrial shrinkTrial (\r -> checked r f)
  where
    shrinkTrial (Right (e,b,p)) = [Right (s,b,p) | s <- children e]
    shrinkTrial (Left _) = []
    children (Translate _ a) = [a]
    children (Union a b) = [a,b]
    children (Intersection a b) = [a,b]
    children (Difference a b) = [a,b]
    children _ = []

containment :: (SDF -> Box3 -> Either String Interval) -> Property
containment analyse = onTrial $ \(e,b,p) -> checked
  ((,) <$> analyse e b <*> evalSDF e p) $ \(i,v) ->
    counterexample (show (i,v)) (property (encloses i v))

csg :: (SDF -> SDF -> SDF) -> (Double -> Double -> Double) -> Property
csg op f = onTrial $ \(e,_,p) -> checked
  ((,) <$> evalSDF (op e (Sphere 1)) p
       <*> (f <$> evalSDF e p <*> evalSDF (Sphere 1) p)) $ \(x,y) -> x === y

translation :: Property
translation = onTrial $ \(e,_,p) -> forAll (genVec 2) $ \et -> checked
  (do t <- et; q <- subVec p t
      (,) <$> evalSDF (Translate t e) p <*> evalSDF e q) $ \(a,b) -> a === b

lipschitzProperty :: Property
lipschitzProperty = onTrial $ \(e,_,p) -> forAll (genVec 5) $ \eq -> checked
  (do q <- eq; delta <- subVec p q
      a <- evalSDF e p; b <- evalSDF e q
      let (x,y,z) = components delta
      distance <- norm3 x y z
      pure (abs (a-b),distance)) $ \(change,distance) ->
        property (change <= distance || near change distance)

dominance :: Property
dominance = onTrial $ \(e,b,_) -> checked
  ((,) <$> evalAbstract e b <*> evalLipschitz e b) $ \(i,l) -> conjoin
    [property (lower l <= lower i || near (lower l) (lower i)),
     property (upper i <= upper l || near (upper i) (upper l))]

corners :: Property
corners = onTrial $ \(e,b,_) -> checked (do
  let (x,y,z) = axes b
  ps <- sequence [vec3 a c d | a <- [lower x,upper x],
                  c <- [lower y,upper y], d <- [lower z,upper z]]
  values <- traverse (evalSDF e) ps
  i <- evalAbstract e b; l <- evalLipschitz e b
  pure (values,i,l)) $ \(values,i,l) ->
    property (all (\v -> encloses i v && encloses l v) values)

knownPrimitives :: Property
knownPrimitives = once $ checked (do
  origin <- vec3 0 0 0
  h <- vec3 1 2 3
  face <- vec3 1 0 0
  outside <- vec3 4 6 3
  pythagoras <- vec3 3 4 0
  sequence [evalSDF (Sphere 2) pythagoras, evalSDF (Box h) origin,
            evalSDF (Box h) face, evalSDF (Box h) outside,
            evalSDF (Box origin) pythagoras]) $ \values ->
    values === [3,-1,0,5,5]

-- check the endpoints against points where each primitive reaches its extremes
primitiveExtrema :: Property
primitiveExtrema = onTrial $ \(_,b,_) -> checked (do
  let (x,y,z) = axes b
      nearest i = max (lower i) (min (upper i) 0)
      farthest i = if abs (lower i) >= abs (upper i) then lower i else upper i
  p <- vec3 (nearest x) (nearest y) (nearest z)
  q <- vec3 (farthest x) (farthest y) (farthest z)
  h <- vec3 1 2 3
  traverse (\e -> do
    i <- evalAbstract e b
    lo <- evalSDF e p; hi <- evalSDF e q
    pure (near (lower i) lo && near (upper i) hi)) [Sphere 1,Box h]) $ \checks ->
      property (and checks)

refinement :: Property
refinement = onTrial $ \(e,b,_) -> conjoin
  [checked (analyse e b) $ \parent -> conjoin
    [checked (analyse e child) $ \i -> conjoin
      [property (lower parent <= lower i || near (lower parent) (lower i)),
       property (upper i <= upper parent || near (upper i) (upper parent))]
    | child <- splitBox b]
  | analyse <- [evalAbstract,evalLipschitz]]

subdivision :: Property
subdivision = onTrial $ \(e,b,p) ->
  let children = splitBox b
      owners = filter (`containsPoint` p) children
      inside child = let (x,y,z) = axes child; (a,c,d) = axes b
                     in and [lower a <= lower x, upper x <= upper a,
                             lower c <= lower y, upper y <= upper c,
                             lower d <= lower z, upper z <= upper d]
  in conjoin [property (length children == 8 && not (null owners)),
              property (all inside children),
              checked (evalSDF e p) $ \v -> conjoin
                [checked (analyse e child) (property . (`encloses` v))
                | child <- owners, analyse <- [evalAbstract,evalLipschitz]]]

classification :: Property
classification = onTrial $ \(e,b,p) -> checked (evalSDF e p) $ \v -> conjoin
  [checked (analyse e b) $ \i -> property $ case classify i of
     PossiblySurface -> contains i 0
     DefinitelyEmpty -> (upper i < 0 && (v < 0 || near v 0))
                    || (lower i > 0 && (v > 0 || near v 0))
  | analyse <- [evalAbstract,evalLipschitz]]

arithmetic :: Property
arithmetic = forAll (vectorOf 4 (choose (-10,10))) $ \xs ->
  case xs of
    [a,b,c,d] -> checked (do
      i <- interval (min a b) (max a b)
      j <- interval (min c d) (max c d)
      s <- addI i j; t <- subI i j; m <- mulI i j
      q <- squareI i; root <- sqrtI q
      pure (i,j,s,t,m,q,root)) $ \(i,j,s,t,m,q,root) -> conjoin
        [property (encloses k value) | (k,value) <-
          [(s,a+c),(t,a-c),(m,a*c),(q,a*a),(root,abs a),
           (negI i,-a),(minI i j,min a c),(maxI i j,max a c)]]
    _ -> counterexample "Generator vector length mismatch" False

-- cover invalid inputs and awkward numerical cases that random tests might miss
edgeCases :: Property
edgeCases = once $ checked (do
  origin <- vec3 0 0 0
  atOrigin <- box3 origin origin
  crossing <- interval (-2) 3 >>= squareI
  crossingRoot <- sqrtI crossing
  pure (origin,atOrigin,crossing,crossingRoot)) $ \(o,b,s,r) -> conjoin
    [lower s === 0, upper s === 9, lower r === 0, upper r === 3,
     property (isLeft (interval 1 0)), property (isLeft (point (0/0))),
     property (isLeft (vec3 (1/0) 0 0)),
     property (isLeft (norm3 (1/0) 0 0)),
     property (isLeft (interval (-1) 2 >>= sqrtI)),
     property (isLeft (point 1e308 >>= \i -> addI i i)),
     property (isLeft (evalSDF (Sphere (-1)) o)),
     property (isLeft (evalAbstract (Sphere (1/0)) b)),
     property (isLeft (vec3 (-1) 1 1 >>= \h -> evalLipschitz (Box h) b)),
     property (isLeft (vec3 1 0 0 >>= \p -> box3 p o)),
     property (isLeft (uniformRegions (-1) b)),
     evalSDF (Sphere 0) o === Right 0,
     conjoin [checked (analyse (Sphere 0) b) $ \i ->
                 conjoin [lower i === 0, upper i === 0, classify i === PossiblySurface]
             | analyse <- [evalAbstract,evalLipschitz]],
     conjoin [checked (do
       p <- vec3 scale 0 0; region <- box3 p p
       h <- vec3 (scale/2) (scale/3) (scale/4)
       let e = Difference (Union (Sphere scale) (Translate p (Box h)))
                          (Intersection (Sphere (scale/2)) (Box h))
       v <- evalSDF e p
       i <- evalAbstract e region; j <- evalLipschitz e region
       pure (v,i,j)) $ \(v,i,j) -> property (encloses i v && encloses j v)
       | scale <- [1e-150,1e150]],
     conjoin [checked (do
       p <- vec3 scale 0 0; region <- box3 p p
       v <- evalSDF (Sphere (scale/2)) p
       i <- evalAbstract (Sphere (scale/2)) region
       j <- evalLipschitz (Sphere (scale/2)) region
       pure [v,lower i,upper i,lower j,upper j]) $ \values ->
         property (all (\x -> abs (x/(scale/2)-1) <= 1e-14) values)
       | scale <- [1e-150,1e150]],
     checked (vec3 1e308 0 0) $ \p -> checked (vec3 (-1e308) 0 0) $ \t ->
       property (isLeft (evalSDF (Translate t (Sphere 1)) p))]

-- reuse the seed so a failing run can be repeated
main :: IO ()
main = do
  let properties =
        [("interval containment",containment evalAbstract),
         ("Lipschitz containment",containment evalLipschitz),
         ("translation",translation), ("union",csg Union min),
         ("Lipschitz inequality",lipschitzProperty),
         ("interval precision dominance",dominance), ("corner containment",corners),
         ("primitive extrema",primitiveExtrema), ("uniform refinement",refinement),
         ("intersection",csg Intersection max),
         ("difference",csg Difference (\a b -> max a (-b))),
         ("subdivision containment",subdivision),
         ("classification consistency",classification),
         ("interval arithmetic",arithmetic), ("known primitives",knownPrimitives),
         ("edge cases",edgeCases)]
  results <- mapM (\(name,p) -> do
    putStrLn name
    quickCheckWithResult stdArgs {maxSuccess=1000, replay=Just (mkQCGen 20261114,0)} p)
    properties
  unless (all isSuccess results) exitFailure
