module Riptide.Protocol.Client
  ( Block
  , BlockId
  , CellId
  , ClientCommand(..)
  , CommandFailure
  , ServerEvent(..)
  , Session
  , Track
  , TrackId
  , TrackText
  , ValidationResult(..)
  , decodeServerEvent
  , encodeClientCommand
  ) where

import Prelude

import Data.Argonaut.Core (Json, fromString, stringify)
import Data.Argonaut.Decode (class DecodeJson, JsonDecodeError(..), decodeJson, fromJsonString, printJsonDecodeError, (.:))
import Data.Argonaut.Encode (class EncodeJson, encodeJson)
import Data.Either (Either(..))
import Data.Maybe (Maybe)
import Foreign.Object (Object)

type TrackId = String
type CellId = String
type BlockId = String

type TrackText =
  { trackTextId :: CellId
  , trackTextSource :: String
  }

type Track =
  { trackId :: TrackId
  , trackName :: String
  , trackSlot :: Int
  , trackTexts :: Array TrackText
  , trackActiveText :: Maybe CellId
  , trackSelectedText :: Maybe CellId
  }

type Block =
  { blockId :: BlockId
  , blockName :: String
  , blockCode :: String
  , blockApplied :: String
  }

type Session =
  { sessionSlotCapacity :: Int
  , sessionTracks :: Array Track
  , sessionDefinitions :: Array Block
  }

data ClientCommand
  = ValidateText String
  | ActivateTrackText TrackId CellId
  | SilenceTrack TrackId
  | SaveTrackText TrackId CellId String
  | SaveDefinition BlockId String String
  | ApplyDefinition BlockId

derive instance eqClientCommand :: Eq ClientCommand

instance showClientCommand :: Show ClientCommand where
  show = case _ of
    ValidateText text -> "(ValidateText " <> show text <> ")"
    ActivateTrackText trackId cellId -> "(ActivateTrackText " <> show trackId <> " " <> show cellId <> ")"
    SilenceTrack trackId -> "(SilenceTrack " <> show trackId <> ")"
    SaveTrackText trackId cellId text -> "(SaveTrackText " <> show trackId <> " " <> show cellId <> " " <> show text <> ")"
    SaveDefinition blockId name code -> "(SaveDefinition " <> show blockId <> " " <> show name <> " " <> show code <> ")"
    ApplyDefinition blockId -> "(ApplyDefinition " <> show blockId <> ")"

encodeClientCommand :: ClientCommand -> String
encodeClientCommand = case _ of
  ValidateText text ->
    object
      [ field "type" "validateText"
      , field "text" text
      ]
  ActivateTrackText trackId cellId ->
    object
      [ field "type" "activateTrackText"
      , field "trackId" trackId
      , field "textId" cellId
      ]
  SilenceTrack trackId ->
    object
      [ field "type" "silenceTrack"
      , field "trackId" trackId
      ]
  SaveTrackText trackId cellId text ->
    object
      [ field "type" "saveTrackText"
      , field "trackId" trackId
      , field "textId" cellId
      , field "text" text
      ]
  SaveDefinition blockId name code ->
    object
      [ field "type" "saveDefinition"
      , field "definitionId" blockId
      , field "name" name
      , field "code" code
      ]
  ApplyDefinition blockId ->
    object
      [ field "type" "applyDefinition"
      , field "definitionId" blockId
      ]

instance encodeJsonClientCommand :: EncodeJson ClientCommand where
  encodeJson command =
    case fromJsonString (encodeClientCommand command) of
      Right json -> json
      Left _ -> encodeJson {}

instance decodeJsonClientCommand :: DecodeJson ClientCommand where
  decodeJson json = do
    value <- decodeJson json :: Either JsonDecodeError (Object Json)
    commandType <- value .: "type"
    case commandType of
      "validateText" ->
        ValidateText <$> value .: "text"
      "activateTrackText" ->
        ActivateTrackText <$> value .: "trackId" <*> value .: "textId"
      "silenceTrack" ->
        SilenceTrack <$> value .: "trackId"
      "saveTrackText" ->
        SaveTrackText <$> value .: "trackId" <*> value .: "textId" <*> value .: "text"
      "saveDefinition" ->
        SaveDefinition <$> value .: "definitionId" <*> value .: "name" <*> value .: "code"
      "applyDefinition" ->
        ApplyDefinition <$> value .: "definitionId"
      other ->
        Left (unknownTag "ClientCommand" other)

data ValidationResult
  = ValidationSucceeded String
  | ValidationFailed String String

derive instance eqValidationResult :: Eq ValidationResult

instance showValidationResult :: Show ValidationResult where
  show = case _ of
    ValidationSucceeded text -> "(ValidationSucceeded " <> show text <> ")"
    ValidationFailed text message -> "(ValidationFailed " <> show text <> " " <> show message <> ")"

instance decodeJsonValidationResult :: DecodeJson ValidationResult where
  decodeJson json = do
    value <- decodeJson json :: Either JsonDecodeError (Object Json)
    resultType <- value .: "type"
    case resultType of
      "validationSucceeded" ->
        ValidationSucceeded <$> value .: "text"
      "validationFailed" ->
        ValidationFailed <$> value .: "text" <*> value .: "message"
      other ->
        Left (unknownTag "ValidationResult" other)

type CommandFailure =
  { command :: ClientCommand
  , message :: String
  }

data ServerEvent
  = StateSnapshot Session
  | TextValidated ValidationResult
  | CommandFailed CommandFailure

derive instance eqServerEvent :: Eq ServerEvent

instance showServerEvent :: Show ServerEvent where
  show = case _ of
    StateSnapshot session -> "(StateSnapshot " <> show session <> ")"
    TextValidated result -> "(TextValidated " <> show result <> ")"
    CommandFailed failure -> "(CommandFailed " <> show failure <> ")"

decodeServerEvent :: String -> Either String ServerEvent
decodeServerEvent source =
  case fromJsonString source of
    Left err -> Left (printJsonDecodeError err)
    Right event -> Right event

instance decodeJsonServerEvent :: DecodeJson ServerEvent where
  decodeJson json = do
    value <- decodeJson json :: Either JsonDecodeError (Object Json)
    eventType <- value .: "type"
    case eventType of
      "stateSnapshot" ->
        StateSnapshot <$> value .: "session"
      "textValidated" ->
        TextValidated <$> value .: "result"
      "commandFailed" ->
        CommandFailed <$> value .: "failure"
      other ->
        Left (unknownTag "ServerEvent" other)

field :: String -> String -> String
field key value =
  quote key <> ":" <> quote value

object :: Array String -> String
object fields =
  "{" <> joinWithComma fields <> "}"

joinWithComma :: Array String -> String
joinWithComma = case _ of
  [] -> ""
  [ one ] -> one
  [ one, two ] -> one <> "," <> two
  [ one, two, three ] -> one <> "," <> two <> "," <> three
  [ one, two, three, four ] -> one <> "," <> two <> "," <> three <> "," <> four
  fields -> stringify (encodeJson fields)

quote :: String -> String
quote =
  stringify <<< fromString

unknownTag :: String -> String -> JsonDecodeError
unknownTag name tag =
  TypeMismatch (name <> " tag " <> tag)
