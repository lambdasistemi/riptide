module Riptide.ProtocolSpec
    ( spec
    ) where

import Data.Aeson (decode, encode)
import Data.Text (Text)
import Data.Text qualified as Text
import Riptide.Protocol
    ( ClientCommand (..)
    , CommandFailure (..)
    , ServerEvent (..)
    , ValidationResult (..)
    )
import Riptide.Session
    ( DefinitionBlock (..)
    , DefinitionId (..)
    , Session (..)
    , Slot (..)
    , TextId (..)
    , Track (..)
    , TrackId (..)
    , TrackText (..)
    )
import Test.Hspec (Spec, describe)
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck
    ( Gen
    , chooseInt
    , elements
    , forAll
    , sublistOf
    )

spec :: Spec
spec =
    describe "Riptide.Protocol JSON" $ do
        prop "round-trips client commands" $
            forAll genClientCommand $ \command ->
                decode (encode command) == Just command

        prop "round-trips server events" $
            forAll genServerEvent $ \event ->
                decode (encode event) == Just event

genClientCommand :: Gen ClientCommand
genClientCommand = do
    track <- genTrackId
    text <- genTextId
    definition <- genDefinitionId
    source <- genSourceText
    name <- genNameText
    elements
        [ ValidateText source
        , ActivateTrackText track text
        , SilenceTrack track
        , SaveTrackText track text source
        , SaveDefinition definition name source
        , ApplyDefinition definition
        ]

genServerEvent :: Gen ServerEvent
genServerEvent = do
    session <- genSession
    command <- genClientCommand
    message <- genMessageText
    result <- genValidationResult
    elements
        [ StateSnapshot session
        , TextValidated result
        , CommandFailed $
            CommandFailure
                { failureCommand = command
                , failureMessage = message
                }
        ]

genValidationResult :: Gen ValidationResult
genValidationResult = do
    source <- genSourceText
    message <- genMessageText
    elements
        [ ValidationSucceeded source
        , ValidationFailed source message
        ]

genSession :: Gen Session
genSession = do
    slotCapacity <- chooseInt (0, 8)
    trackCount <- chooseInt (0, slotCapacity)
    tracks <- genTracks trackCount
    definitions <- genDefinitions
    pure
        Session
            { sessionSlotCapacity = slotCapacity
            , sessionTracks = tracks
            , sessionDefinitions = definitions
            }

genTracks :: Int -> Gen [Track]
genTracks count =
    traverse genTrack [1 .. count]

genTrack :: Int -> Gen Track
genTrack index = do
    texts <- genTrackTexts index
    active <- genTextReference texts
    selected <- genTextReference texts
    pure
        Track
            { trackId = TrackId $ numberedText "track" index
            , trackName = numberedText "Track" index
            , trackSlot = Slot index
            , trackTexts = texts
            , trackActiveText = active
            , trackSelectedText = selected
            }

genTrackTexts :: Int -> Gen [TrackText]
genTrackTexts trackIndex = do
    count <- chooseInt (0, 4)
    traverse (genTrackText trackIndex) [1 .. count]

genTrackText :: Int -> Int -> Gen TrackText
genTrackText trackIndex index =
    pure
        TrackText
            { trackTextId =
                TextId $ numberedText ("text-" <> show trackIndex) index
            , trackTextSource = "sound \"" <> numberedText "bd" index <> "\""
            }

genTextReference :: [TrackText] -> Gen (Maybe TextId)
genTextReference texts = do
    selected <- sublistOf $ fmap trackTextId texts
    case selected of
        ident : _ -> elements [Nothing, Just ident]
        [] -> pure Nothing

genDefinitions :: Gen [DefinitionBlock]
genDefinitions = do
    count <- chooseInt (0, 4)
    traverse genDefinition [1 .. count]

genDefinition :: Int -> Gen DefinitionBlock
genDefinition index =
    pure
        DefinitionBlock
            { blockId = DefinitionId $ numberedText "defs" index
            , blockName = numberedText "Definition" index
            , blockCode = "let density = " <> numberedText "" index
            , blockApplied = "let density = " <> numberedText "" (index + 1)
            }

genTrackId :: Gen TrackId
genTrackId =
    TrackId . numberedText "track" <$> chooseInt (1, 8)

genTextId :: Gen TextId
genTextId =
    TextId . numberedText "text" <$> chooseInt (1, 8)

genDefinitionId :: Gen DefinitionId
genDefinitionId =
    DefinitionId . numberedText "defs" <$> chooseInt (1, 8)

genSourceText :: Gen Text
genSourceText =
    elements
        [ "sound \"bd\""
        , "stack [sound \"bd\", sound \"sn\"]"
        , "let density = 2"
        ]

genNameText :: Gen Text
genNameText =
    elements ["drums", "bass", "shared definitions"]

genMessageText :: Gen Text
genMessageText =
    elements ["parse error", "unknown track", "playback failed"]

numberedText :: String -> Int -> Text
numberedText prefix index =
    Text.pack $ prefix <> "-" <> show index
