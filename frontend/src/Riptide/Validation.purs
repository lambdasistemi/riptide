module Riptide.Validation
  ( AuthoritativeValidation
  , ValidationResult
  , authoritativeValidation
  , recordAuthoritativeValidation
  , valid
  ) where

import Prelude

import Data.Array (filter, length, uncons)
import Data.Array as Array
import Data.Maybe (Maybe(..))
import Data.String.CodeUnits as CodeUnits
import Data.String.Common as String

type ValidationResult =
  { empty :: Boolean
  , valid :: Boolean
  , error :: Maybe String
  }

type AuthoritativeValidation =
  { source :: String
  , valid :: Boolean
  , error :: Maybe String
  }

authoritativeValidation :: Array AuthoritativeValidation -> String -> ValidationResult
authoritativeValidation backend code =
  case Array.find (_.source >>> (_ == code)) backend of
    Just result ->
      { empty: String.trim code == ""
      , valid: result.valid
      , error: result.error
      }
    Nothing ->
      valid code

recordAuthoritativeValidation :: AuthoritativeValidation -> Array AuthoritativeValidation -> Array AuthoritativeValidation
recordAuthoritativeValidation result backend =
  [ result ] <> Array.filter (_.source >>> (_ /= result.source)) backend

valid :: String -> ValidationResult
valid code =
  let
    s = String.trim code
  in
    if s == "" then
      { empty: true, valid: false, error: Nothing }
    else if countChar '"' s `mod` 2 /= 0 then
      invalid "unbalanced quote"
    else case scanParens (CodeUnits.toCharArray s) of
      Just err -> invalid err
      Nothing -> case scanBrackets (CodeUnits.toCharArray s) of
        Just err -> invalid err
        Nothing -> { empty: false, valid: true, error: Nothing }

invalid :: String -> ValidationResult
invalid error =
  { empty: false
  , valid: false
  , error: Just error
  }

countChar :: Char -> String -> Int
countChar needle =
  length <<< filter (_ == needle) <<< CodeUnits.toCharArray

scanParens :: Array Char -> Maybe String
scanParens =
  scanBalanced '(' ')' "unmatched )" "missing )"

scanBrackets :: Array Char -> Maybe String
scanBrackets =
  scanBalanced '[' ']' "unmatched ]" "missing ]"

scanBalanced :: Char -> Char -> String -> String -> Array Char -> Maybe String
scanBalanced open close unmatched missing chars =
  go 0 chars
  where
  go depth xs = case xs of
    [] ->
      if depth == 0 then Nothing else Just missing
    _ -> case uncons xs of
      Just { head: c, tail: rest }
        | c == open -> go (depth + 1) rest
        | c == close ->
            if depth == 0 then Just unmatched else go (depth - 1) rest
        | otherwise -> go depth rest
      Nothing ->
        if depth == 0 then Nothing else Just missing
