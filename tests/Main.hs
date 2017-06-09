module Main where

import qualified LLVM.Module as M
import LLVM.Context
import LLVM.Pretty (ppllvm)

import Control.Monad (filterM)
import Control.Monad.Except

import Data.Functor
import qualified Data.Text.Lazy as T
import qualified Data.Text.Lazy.IO as T
import Text.Show.Pretty (ppShow)

import System.IO
import System.Exit
import System.Directory
import System.FilePath
import System.Environment

-------------------------------------------------------------------------------
-- Harness
-------------------------------------------------------------------------------

readir :: FilePath -> IO ()
readir fname = do
  str <- readFile fname
  withContext $ \ctx -> do
    res <- runExceptT $ M.withModuleFromLLVMAssembly ctx str $ \mod -> do
      ast <- M.moduleAST mod
      let str = ppllvm ast
      T.writeFile ("tests/output" </> takeFileName fname) str
      trip <- runExceptT $ M.withModuleFromLLVMAssembly ctx (T.unpack str) (const $ return ())
      case trip of
        Left err -> do
          putStrLn $ "Error : " ++ fname
          putStrLn err
          writeFile ("tests/output" </> takeFileName fname) err
          exitFailure
        Right ast -> putStrLn $ "OK : " ++ fname

    case res of
      Left err -> do
        putStrLn "Error reading input:"
        putStrLn err
        writeFile ("tests/output" </> takeFileName fname) err
        exitFailure
      Right _ -> return ()

main :: IO ()
main = do
  putStrLn ""
  files <- getArgs

  case files of
    [] -> do
      let testPath = "tests/input/"
      dirFiles <- listDirectory testPath
      mapM_ readir (fmap (\x -> testPath </> x) dirFiles)
    [fpath] -> readir fpath
    _  -> mapM_ readir files

  putStrLn "All good."
  return ()
