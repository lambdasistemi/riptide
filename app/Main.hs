module Main
    ( main
    ) where

import Riptide (banner)
import Riptide.Eval (interpretControlPattern)
import Riptide.Server (runServerFromEnvironment)
import System.Environment (getArgs)

main :: IO ()
main = do
    args <- getArgs
    case args of
        ("eval" : rest) -> evalCommand (unwords rest)
        ["serve"] -> runServerFromEnvironment
        _ -> putStrLn banner

{- | Interpret a Tidal expression from the command line, for smoke-testing the
hint/tidal wiring. Prints the compiled pattern or the compiler error.
-}
evalCommand :: String -> IO ()
evalCommand code = do
    result <- interpretControlPattern code
    case result of
        Left err -> do
            putStrLn "INVALID:"
            print err
        Right pat -> do
            putStrLn "VALID ControlPattern:"
            print pat
