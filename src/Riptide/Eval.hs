module Riptide.Eval
    ( interpretControlPattern
    , interpretControlPatternWithDefinitions
    , validateControlPattern
    , validateControlPatternWithDefinitions
    ) where

-- \|
-- Module      : Riptide.Eval
-- Description : Interpret and validate track text as a Tidal ControlPattern.
-- Copyright   : (c) Paolo Veronelli, 2026
-- License     : BSD-3-Clause
--
-- The @tidal@ library is compiled into this binary, and @hint@ (the GHC API) is
-- used to turn a track's source text into a 'ControlPattern' value at runtime —
-- without spawning a GHCi subprocess. Validation type-checks the text and
-- produces no sound; only activation (elsewhere) plays it.
--
-- The interpreter session needs a GHC package database that exposes @tidal@. That
-- database is provided by the Nix wrapper, which points 'interpLibdir' at a
-- @ghcWithPackages@ GHC through the @RIPTIDE_GHC@ environment variable.

import Data.Char (isSpace)
import Data.List (dropWhileEnd, intercalate, isPrefixOf)
import Data.Maybe (fromMaybe)
import Language.Haskell.Interpreter
    ( InterpreterError
    , as
    , interpret
    , setImports
    )
import Language.Haskell.Interpreter.Unsafe
    ( unsafeRunInterpreterWithArgsLibdir
    )
import Sound.Tidal.Context (ControlPattern)
import System.Environment (lookupEnv)
import System.Process (readProcess)

{- |
Modules in scope when interpreting a track's text. @Data.Map@ is needed because
hint renders the expected return type from 'Typeable' as the fully-expanded
@Pattern (Map String Value)@, so @Map@ must be in scope.
-}
tidalImports :: [String]
tidalImports =
    [ "Prelude"
    , "Sound.Tidal.Context"
    , "Data.Map"
    ]

{- |
GHC arguments for every interpreter session. Tidal's mini-notation depends on
@OverloadedStrings@ (a string literal becomes a @Pattern@ via its @IsString@
instance), exactly as Tidal's own @BootTidal.hs@ sets it.
-}
interpArgs :: [String]
interpArgs = ["-XOverloadedStrings"]

{- |
Discover the GHC libdir whose package database exposes @tidal@, by asking the
interpreter GHC pointed to by @RIPTIDE_GHC@ (falling back to @ghc@ on @PATH@).
-}
interpLibdir :: IO String
interpLibdir = do
    ghc <- fromMaybe "ghc" <$> lookupEnv "RIPTIDE_GHC"
    dropWhileEnd (== '\n')
        <$> readProcess ghc ["--print-libdir"] ""

{- |
Interpret track text as a 'ControlPattern'. Returns the compiled value on
success, or the compiler error on failure. Produces no sound.
-}
interpretControlPattern
    :: String
    -> IO (Either InterpreterError ControlPattern)
interpretControlPattern =
    interpretControlPatternWithDefinitions []

{- |
Interpret track text as a 'ControlPattern' with active definition bindings in
scope. Each definition block may start with a leading @let @, matching the saved
session representation.
-}
interpretControlPatternWithDefinitions
    :: [String]
    -> String
    -> IO (Either InterpreterError ControlPattern)
interpretControlPatternWithDefinitions definitions code = do
    libdir <- interpLibdir
    unsafeRunInterpreterWithArgsLibdir interpArgs libdir $ do
        setImports tidalImports
        interpret
            (controlPatternExpression definitions code)
            (as :: ControlPattern)

{- |
Validate that track text type-checks as a 'ControlPattern', without evaluating
it. This is the authoritative gate before a track may be activated.
-}
validateControlPattern
    :: String
    -> IO (Either InterpreterError Bool)
validateControlPattern =
    validateControlPatternWithDefinitions []

{- |
Validate that track text type-checks as a 'ControlPattern' with active
definition bindings in scope.
-}
validateControlPatternWithDefinitions
    :: [String]
    -> String
    -> IO (Either InterpreterError Bool)
validateControlPatternWithDefinitions definitions code = do
    libdir <- interpLibdir
    unsafeRunInterpreterWithArgsLibdir interpArgs libdir $ do
        setImports tidalImports
        _ <-
            interpret
                (controlPatternExpression definitions code)
                (as :: ControlPattern)
        pure True

controlPatternExpression :: [String] -> String -> String
controlPatternExpression definitions code =
    case normalizeDefinition <$> definitions of
        [] -> scopedCode
        bindings ->
            "let { " <> intercalate " ; " bindings <> " } in " <> scopedCode
  where
    scopedCode = "(" <> code <> ") :: ControlPattern"

normalizeDefinition :: String -> String
normalizeDefinition source =
    case dropWhile isSpace source of
        trimmed
            | "let " `isPrefixOf` trimmed ->
                drop 4 trimmed
            | otherwise ->
                trimmed
