module Main (main) where

import Abstract
import Concrete
import Control.DeepSeq (force)
import Control.Exception (IOException, catch, evaluate)
import Control.Monad (forM_, foldM)
import Data.IORef (newIORef, readIORef)
import Data.List (intercalate)
import Interval
import Lipschitz
import Scenes
import Spatial
import Syntax
import System.CPUTime (getCPUTime)
import System.Environment (getArgs)
import System.Exit (die)
import System.IO (IOMode(WriteMode), hPutStrLn, withFile)
import Text.Read (readMaybe)

type Analysis = SDF -> Box3 -> Either String Interval

methods :: [(String,Analysis)]
methods = [("interval",evalAbstract),("lipschitz",evalLipschitz)]

require :: Either String a -> IO a
require = either die pure

-- keep this separate so benchmark trials do not reuse an earlier result
{-# NOINLINE summarise #-}
summarise :: Analysis -> SDF -> [Box3] -> Either String (Double,Int)
summarise analyse e = foldM step (0,0)
  where
    step (total,empty) b = do
      i <- analyse e b
      w <- width i
      total' <- finite (total+w)
      let empty' = empty + if classify i == DefinitelyEmpty then 1 else 0
      total' `seq` empty' `seq` Right (total',empty')

time :: IO a -> IO (a,Double)
time action = do
  start <- getCPUTime
  result <- action
  end <- getCPUTime
  pure (result,fromIntegral (end-start)/1e9)

benchmark :: FilePath -> Int -> Int -> IO ()
benchmark path depth repetitions = do
  examples <- require scenes
  root <- require benchmarkRegion
  withFile path WriteMode $ \h -> do
    hPutStrLn h "scene,depth,method,trial,regions,subdivisions,mean_width,empty_regions,empty_fraction,cpu_ms,subdivision_cpu_ms"
    forM_ [0..depth] $ \d -> do
      (regions,subTime) <- time $ do
        bs <- require (uniformRegions d root)
        -- finish building the cells before timing either analysis
        _ <- evaluate (force [let (x,y,z) = axes b in
          (lower x,upper x,lower y,upper y,lower z,upper z) | b <- bs])
        pure bs
      let count = length regions
      forM_ examples $ \(name,e) -> do
        inputs <- newIORef (e,regions)
        -- warm up both methods before collecting timings
        forM_ methods $ \(_,analyse) -> do
          (expr,bs) <- readIORef inputs
          _ <- evaluate (force (summarise analyse expr bs)) >>= require
          pure ()
        forM_ [1..repetitions] $ \trial -> do
          -- take turns going first so the timing order does not favour one method
          let ordered = if even trial then reverse methods else methods
          forM_ ordered $ \(label,analyse) -> do
            (answer,elapsed) <- time $ do
              (expr,bs) <- readIORef inputs
              evaluate (force (summarise analyse expr bs))
            (total,empty) <- require answer
            hPutStrLn h $ intercalate ","
              [name,show d,label,show trial,show count,show ((count-1) `div` 7),
               show (total/fromIntegral count),show empty,
               show (fromIntegral empty/fromIntegral count :: Double),
               show elapsed,show subTime]
  putStrLn ("Wrote approximate numerical measurements to " ++ path)

-- put both methods side by side using the same cells through the middle of the scene
renderSlice :: FilePath -> Int -> IO ()
renderSlice path size = do
  examples <- require scenes
  e <- require $ maybe (Left "Missing nested scene") Right (lookup "nested" examples)
  withFile path WriteMode $ \h -> do
    hPutStrLn h "P3"
    hPutStrLn h "# compare approximate surface classifications at z=0 with interval left and lipschitz right"
    hPutStrLn h (show (2*size) ++ " " ++ show size)
    hPutStrLn h "255"
    forM_ [0..size-1] $ \row -> forM_ methods $ \(_,analyse) ->
      forM_ [0..size-1] $ \col -> do
        let edge i = -2.5 + 5 * fromIntegral i / fromIntegral size
        b <- require $ do
          lo <- vec3 (edge col) (edge (size-row-1)) 0
          hi <- vec3 (edge (col+1)) (edge (size-row)) 0
          box3 lo hi
        i <- require (analyse e b)
        hPutStrLn h $ case classify i of
          DefinitelyEmpty -> "238 241 245"
          PossiblySurface -> "33 91 154"
  putStrLn ("Wrote slice: " ++ path)

bounded :: String -> Int -> Int -> String -> IO Int
bounded label lo hi input = case readMaybe input of
  Just n | n >= lo && n <= hi -> pure n
  _ -> die (label ++ " must be an integer in [" ++ show lo ++ "," ++ show hi ++ "]")

run :: [String] -> IO ()
run ["bench",path,d,n] = do
  depth <- bounded "Depth" 0 5 d
  repetitions <- bounded "Repetitions" 1 1000 n
  benchmark path depth repetitions
run ["slice",path,n] = bounded "Resolution" 1 1024 n >>= renderSlice path
run [] = do
  b <- require benchmarkRegion
  p <- require (centre b)
  examples <- require scenes
  putStrLn "Double approximations; real-arithmetic soundness only."
  forM_ examples $ \(name,e) -> do
    v <- require (evalSDF e p)
    ranges <- require (traverse (\(_,a) -> a e b) methods)
    putStrLn (name ++ ": centre=" ++ show v ++ "; interval, Lipschitz=" ++ show ranges)
run _ = die "Usage: sdf-analyse [bench OUTPUT.csv DEPTH REPEATS | slice OUTPUT.ppm RESOLUTION]"

main :: IO ()
main = catch (getArgs >>= run) handler
  where handler :: IOException -> IO ()
        handler = die . show
