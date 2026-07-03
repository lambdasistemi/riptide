module Riptide.Helpers
  ( CascadeEntry
  , CascadeResult
  , cascade
  , collectBlockIds
  , collectIds
  , definedNames
  , duplicateIds
  , duplicateStrings
  , effectiveSelected
  , normalizeScore
  ) where

import Prelude

import Data.Array as Array
import Data.Char (toCharCode)
import Data.Foldable (foldl)
import Data.Maybe (Maybe(..))
import Data.String.CodeUnits as CodeUnits
import Data.String.Common as String
import Data.String.Pattern (Pattern(..))
import Riptide.Model (Block, Cell, Song, Toolbox, Track, totalBars)

type CascadeEntry =
  { loc :: String
  , code :: String
  }

type CascadeResult =
  { names :: Array String
  , count :: Int
  , list :: Array CascadeEntry
  }

definedNames :: String -> Array String
definedNames code =
  Array.mapMaybe definedNameOnLine (String.split (Pattern "\n") code)

cascade :: Array Song -> Block -> CascadeResult
cascade songs block =
  let
    names = Array.nubEq (definedNames block.applied <> definedNames block.code)
    entries = matchingEntries names songs
  in
    { names
    , count: Array.length entries
    , list: Array.take 5 entries
    }

effectiveSelected :: Track -> Maybe Cell
effectiveSelected track = case track.selected of
  Just selected ->
    case Array.find (_.id >>> (_ == selected)) track.cells of
      Just cell -> Just cell
      Nothing -> Array.head track.cells
  Nothing -> Array.head track.cells

normalizeScore :: Array Boolean -> Array Boolean
normalizeScore score =
  Array.take totalBars (score <> emptyScore)

collectIds :: Array Song -> Array String
collectIds =
  Array.concatMap collectSongIds

collectBlockIds :: Array Toolbox -> Array String
collectBlockIds =
  Array.concatMap \toolbox ->
    [ toolbox.id ] <> map _.id toolbox.blocks

duplicateIds :: Array Song -> Array String
duplicateIds =
  duplicateStrings <<< collectIds

duplicateStrings :: Array String -> Array String
duplicateStrings ids =
  (Array.nubEq <<< _.duplicates) (foldl step { seen: [], duplicates: [] } ids)
  where
  step acc id =
    if Array.elem id acc.seen then
      acc { duplicates = acc.duplicates <> [ id ] }
    else
      acc { seen = acc.seen <> [ id ] }

definedNameOnLine :: String -> Maybe String
definedNameOnLine line =
  readBindingName (dropOptionalLet (String.trim line))

dropOptionalLet :: String -> String
dropOptionalLet line =
  case CodeUnits.stripPrefix (Pattern "let") line of
    Just rest
      | startsWithSpace rest -> String.trim rest
    _ -> line

readBindingName :: String -> Maybe String
readBindingName line =
  let
    chars = CodeUnits.toCharArray line
    nameChars = Array.takeWhile isNameChar chars
    rest = CodeUnits.fromCharArray (Array.drop (Array.length nameChars) chars)
    name = CodeUnits.fromCharArray nameChars
  in
    if name == "" then
      Nothing
    else if not (isNameStart (unsafeFirst nameChars)) then
      Nothing
    else if isAssignmentRest rest then
      Just name
    else
      Nothing

isAssignmentRest :: String -> Boolean
isAssignmentRest rest =
  CodeUnits.stripPrefix (Pattern "=") (String.trim rest) /= Nothing

matchingEntries :: Array String -> Array Song -> Array CascadeEntry
matchingEntries names songs =
  if Array.null names then
    []
  else
    Array.concatMap songEntries songs
  where
  songEntries song =
    Array.concatMap (trackEntries song.name) song.tracks

  trackEntries songName track =
    map
      (\cell -> { loc: songName <> " › " <> track.name, code: cell.code })
      (Array.filter (cellMatches names) track.cells)

cellMatches :: Array String -> Cell -> Boolean
cellMatches names cell =
  Array.any (\name -> containsWholeWord name cell.code) names

containsWholeWord :: String -> String -> Boolean
containsWholeWord name code =
  go Nothing (CodeUnits.toCharArray code)
  where
  needle = CodeUnits.toCharArray name
  needleLength = Array.length needle

  go previous chars =
    if Array.length chars < needleLength then
      false
    else if startsWithArray needle chars && boundaryBefore previous && boundaryAfter chars then
      true
    else
      case Array.uncons chars of
        Just { head, tail } -> go (Just head) tail
        Nothing -> false

  boundaryBefore previous =
    case previous of
      Just c -> not (isWordChar c)
      Nothing -> true

  boundaryAfter chars =
    case Array.index chars needleLength of
      Just c -> not (isWordChar c)
      Nothing -> true

startsWithArray :: Array Char -> Array Char -> Boolean
startsWithArray needle haystack =
  Array.take (Array.length needle) haystack == needle

collectSongIds :: Song -> Array String
collectSongIds song =
  [ song.id ] <> Array.concatMap collectTrackIds song.tracks

collectTrackIds :: Track -> Array String
collectTrackIds track =
  [ track.id ] <> map _.id track.cells

emptyScore :: Array Boolean
emptyScore =
  [ false
  , false
  , false
  , false
  , false
  , false
  , false
  , false
  , false
  , false
  , false
  , false
  , false
  , false
  , false
  , false
  ]

startsWithSpace :: String -> Boolean
startsWithSpace rest =
  case CodeUnits.charAt 0 rest of
    Just c -> isSpace c
    Nothing -> false

isNameStart :: Char -> Boolean
isNameStart c =
  c == '_' || isAsciiLetter c

isNameChar :: Char -> Boolean
isNameChar c =
  isNameStart c || isAsciiDigit c

isWordChar :: Char -> Boolean
isWordChar =
  isNameChar

isAsciiLetter :: Char -> Boolean
isAsciiLetter c =
  let
    n = toCharCode c
  in
    (n >= toCharCode 'A' && n <= toCharCode 'Z')
      || (n >= toCharCode 'a' && n <= toCharCode 'z')

isAsciiDigit :: Char -> Boolean
isAsciiDigit c =
  let
    n = toCharCode c
  in
    n >= toCharCode '0' && n <= toCharCode '9'

isSpace :: Char -> Boolean
isSpace c =
  c == ' ' || c == '\t'

unsafeFirst :: Array Char -> Char
unsafeFirst chars =
  case Array.head chars of
    Just c -> c
    Nothing -> '_'
