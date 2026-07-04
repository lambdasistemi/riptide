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
import Data.Maybe (Maybe(..))
import Data.String.Common as String
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
  | SetSession Session
  | ActivateTrackText TrackId CellId
  | SilenceTrack TrackId
  | SaveTrackText TrackId CellId String
  | SaveDefinition BlockId String String
  | ApplyDefinition BlockId

derive instance eqClientCommand :: Eq ClientCommand

instance showClientCommand :: Show ClientCommand where
  show = case _ of
    ValidateText text -> "(ValidateText " <> show text <> ")"
    SetSession session -> "(SetSession " <> show session <> ")"
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
  SetSession session ->
    object
      [ field "type" "setSession"
      , fieldJson "session" (sessionJson session)
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
      "setSession" ->
        SetSession <$> value .: "session"
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

fieldJson :: String -> String -> String
fieldJson key value =
  quote key <> ":" <> value

object :: Array String -> String
object fields =
  "{" <> joinWithComma fields <> "}"

sessionJson :: Session -> String
sessionJson session =
  object
    [ fieldJson "sessionSlotCapacity" (show session.sessionSlotCapacity)
    , fieldJson "sessionTracks" (arrayJson trackJson session.sessionTracks)
    , fieldJson "sessionDefinitions" (arrayJson blockJson session.sessionDefinitions)
    ]

trackJson :: Track -> String
trackJson track =
  object
    [ field "trackId" track.trackId
    , field "trackName" track.trackName
    , fieldJson "trackSlot" (show track.trackSlot)
    , fieldJson "trackTexts" (arrayJson trackTextJson track.trackTexts)
    , fieldJson "trackActiveText" (maybeStringJson track.trackActiveText)
    , fieldJson "trackSelectedText" (maybeStringJson track.trackSelectedText)
    ]

trackTextJson :: TrackText -> String
trackTextJson text =
  object
    [ field "trackTextId" text.trackTextId
    , field "trackTextSource" text.trackTextSource
    ]

blockJson :: Block -> String
blockJson block =
  object
    [ field "blockId" block.blockId
    , field "blockName" block.blockName
    , field "blockCode" block.blockCode
    , field "blockApplied" block.blockApplied
    ]

arrayJson :: forall a. (a -> String) -> Array a -> String
arrayJson encode =
  case _ of
    [] -> "[]"
    values -> "[" <> joinWithComma (map encode values) <> "]"

maybeStringJson :: Maybe String -> String
maybeStringJson = case _ of
  Just value -> quote value
  Nothing -> "null"

joinWithComma :: Array String -> String
joinWithComma =
  String.joinWith ","

quote :: String -> String
quote =
  stringify <<< fromString

unknownTag :: String -> String -> JsonDecodeError
unknownTag name tag =
  TypeMismatch (name <> " tag " <> tag)
