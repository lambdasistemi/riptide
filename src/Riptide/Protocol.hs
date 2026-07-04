module Riptide.Protocol
    ( ClientCommand (..)
    , CommandFailure (..)
    , ServerEvent (..)
    , ValidationResult (..)
    ) where

-- \|
-- Module      : Riptide.Protocol
-- Description : JSON wire protocol for the websocket backend.
--
-- The protocol uses tagged JSON objects with named fields so messages remain
-- stable when constructors gain fields or frontend code inspects payloads.

import Data.Aeson
    ( FromJSON (..)
    , ToJSON (..)
    , Value
    , object
    , withObject
    , (.:)
    , (.=)
    )
import Data.Aeson.Types (Pair)
import Data.Text (Text)
import Data.Text qualified as Text
import Riptide.Session
    ( DefinitionId
    , Session
    , TextId
    , TrackId
    )

data ClientCommand
    = ValidateText Text
    | ActivateTrackText TrackId TextId
    | SilenceTrack TrackId
    | SaveTrackText TrackId TextId Text
    | SaveDefinition DefinitionId Text Text
    | ApplyDefinition DefinitionId
    deriving stock (Show, Eq)

instance ToJSON ClientCommand where
    toJSON = \case
        ValidateText source ->
            tagged
                "validateText"
                ["text" .= source]
        ActivateTrackText track text ->
            tagged
                "activateTrackText"
                [ "trackId" .= track
                , "textId" .= text
                ]
        SilenceTrack track ->
            tagged
                "silenceTrack"
                ["trackId" .= track]
        SaveTrackText track text source ->
            tagged
                "saveTrackText"
                [ "trackId" .= track
                , "textId" .= text
                , "text" .= source
                ]
        SaveDefinition definition name code ->
            tagged
                "saveDefinition"
                [ "definitionId" .= definition
                , "name" .= name
                , "code" .= code
                ]
        ApplyDefinition definition ->
            tagged
                "applyDefinition"
                ["definitionId" .= definition]

instance FromJSON ClientCommand where
    parseJSON =
        withObject "ClientCommand" $ \value ->
            value .: "type" >>= \case
                "validateText" ->
                    ValidateText
                        <$> value .: "text"
                "activateTrackText" ->
                    ActivateTrackText
                        <$> value .: "trackId"
                        <*> value .: "textId"
                "silenceTrack" ->
                    SilenceTrack
                        <$> value .: "trackId"
                "saveTrackText" ->
                    SaveTrackText
                        <$> value .: "trackId"
                        <*> value .: "textId"
                        <*> value .: "text"
                "saveDefinition" ->
                    SaveDefinition
                        <$> value .: "definitionId"
                        <*> value .: "name"
                        <*> value .: "code"
                "applyDefinition" ->
                    ApplyDefinition
                        <$> value .: "definitionId"
                commandType ->
                    fail $
                        "unknown client command type: "
                            <> Text.unpack commandType

data ValidationResult
    = ValidationSucceeded Text
    | ValidationFailed Text Text
    deriving stock (Show, Eq)

instance ToJSON ValidationResult where
    toJSON = \case
        ValidationSucceeded source ->
            tagged
                "validationSucceeded"
                ["text" .= source]
        ValidationFailed source message ->
            tagged
                "validationFailed"
                [ "text" .= source
                , "message" .= message
                ]

instance FromJSON ValidationResult where
    parseJSON =
        withObject "ValidationResult" $ \value ->
            value .: "type" >>= \case
                "validationSucceeded" ->
                    ValidationSucceeded
                        <$> value .: "text"
                "validationFailed" ->
                    ValidationFailed
                        <$> value .: "text"
                        <*> value .: "message"
                resultType ->
                    fail $
                        "unknown validation result type: "
                            <> Text.unpack resultType

data ServerEvent
    = StateSnapshot Session
    | TextValidated ValidationResult
    | CommandFailed CommandFailure
    deriving stock (Show, Eq)

instance ToJSON ServerEvent where
    toJSON = \case
        StateSnapshot session ->
            tagged
                "stateSnapshot"
                ["session" .= session]
        TextValidated result ->
            tagged
                "textValidated"
                ["result" .= result]
        CommandFailed failure ->
            tagged
                "commandFailed"
                ["failure" .= failure]

instance FromJSON ServerEvent where
    parseJSON =
        withObject "ServerEvent" $ \value ->
            value .: "type" >>= \case
                "stateSnapshot" ->
                    StateSnapshot
                        <$> value .: "session"
                "textValidated" ->
                    TextValidated
                        <$> value .: "result"
                "commandFailed" ->
                    CommandFailed
                        <$> value .: "failure"
                eventType ->
                    fail $
                        "unknown server event type: "
                            <> Text.unpack eventType

data CommandFailure = CommandFailure
    { failureCommand :: ClientCommand
    , failureMessage :: Text
    }
    deriving stock (Show, Eq)

instance ToJSON CommandFailure where
    toJSON CommandFailure{..} =
        object
            [ "command" .= failureCommand
            , "message" .= failureMessage
            ]

instance FromJSON CommandFailure where
    parseJSON =
        withObject "CommandFailure" $ \value ->
            CommandFailure
                <$> value .: "command"
                <*> value .: "message"

tagged :: Text -> [Pair] -> Value
tagged tag fields =
    object $ ("type" .= tag) : fields
