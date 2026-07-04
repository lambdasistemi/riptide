module Riptide.SessionSpec
    ( spec
    ) where

import Data.List (nub)
import Data.Text (Text)
import Data.Text qualified as Text
import Riptide.Session
    ( DefinitionId (..)
    , DefinitionBlock (..)
    , Session (..)
    , Slot (..)
    , TextId (..)
    , Track (..)
    , TrackId (..)
    , TrackText (..)
    , activateTrackText
    , addDefinitionBlock
    , addTrack
    , addTrackText
    , applyDefinitionBlock
    , editDefinitionBlock
    , editTrackText
    , emptySession
    , removeDefinitionBlock
    , removeTrack
    , removeTrackText
    , saveTrackText
    , selectTrackText
    , silenceTrack
    )
import Test.Hspec
    ( Spec
    , describe
    , expectationFailure
    , it
    , shouldBe
    )
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck
    ( Gen
    , chooseInt
    , elements
    , forAll
    , listOf
    , property
    )

spec :: Spec
spec = do
    describe "Riptide.Session tracks" $ do
        it "assigns hidden slots and recycles released slots" $ do
            case addTrack (TrackId "track-kick") "kick" $
                emptySession 2 of
                Nothing -> expectationFailure "expected first slot"
                Just withKick ->
                    case addTrack
                        (TrackId "track-snare")
                        "snare"
                        withKick of
                        Nothing ->
                            expectationFailure "expected second slot"
                        Just withSnare -> do
                            let withoutKick =
                                    removeTrack
                                        (TrackId "track-kick")
                                        withSnare
                            case addTrack
                                (TrackId "track-hat")
                                "hat"
                                withoutKick of
                                Nothing ->
                                    expectationFailure
                                        "expected recycled slot"
                                Just withHat -> do
                                    fmap trackSlot
                                        (sessionTracks withSnare)
                                        `shouldBe` [Slot 1, Slot 2]
                                    fmap trackSlot
                                        (sessionTracks withHat)
                                        `shouldBe` [Slot 2, Slot 1]

        it "keeps selected text when an active text is silenced" $ do
            let session =
                    trackSession
                        & addText "a" "d1 $ sound \"bd\""
                        & addText "b" "d1 $ sound \"sn\""
                        & activate "a"
                        & activate "a"

            trackActiveText <$> firstTrack session `shouldBe` Just Nothing
            trackSelectedText <$> firstTrack session
                `shouldBe` Just (Just $ TextId "a")

        it "activates one text by silencing the previous active text" $ do
            let session =
                    trackSession
                        & addText "a" "d1 $ sound \"bd\""
                        & addText "b" "d1 $ sound \"sn\""
                        & activate "a"
                        & activate "b"

            trackActiveText <$> firstTrack session
                `shouldBe` Just (Just $ TextId "b")
            trackSelectedText <$> firstTrack session
                `shouldBe` Just (Just $ TextId "b")
            fmap (fmap trackTextId . trackTexts) (firstTrack session)
                `shouldBe` Just [TextId "a", TextId "b"]

        it "clears active and selected references when a text is removed" $ do
            let session =
                    trackSession
                        & addText "a" "d1 $ sound \"bd\""
                        & activate "a"
                        & removeTrackText
                            (TrackId "track-a")
                            (TextId "a")

            trackActiveText <$> firstTrack session `shouldBe` Just Nothing
            trackSelectedText <$> firstTrack session `shouldBe` Just Nothing

        it "edits and saves track source text" $ do
            let session =
                    trackSession
                        & addText "a" "sound \"bd\""
                        & editTrackText
                            (TrackId "track-a")
                            (TextId "a")
                            "sound \"sn\""
                        & saveTrackText
                            (TrackId "track-a")
                            (TextId "a")
                            "sound \"hh\""

            fmap trackTextSource
                (firstTrack session >>= firstText)
                `shouldBe` Just "sound \"hh\""

        prop "no track can end with more than one active text" $
            forAll genActivationSession $ \session ->
                property $
                    all hasAtMostOneActiveText (sessionTracks session)

        prop "live track slots are unique after add/remove sequences" $
            forAll genSlotSession $ \session ->
                property $
                    let slots = fmap trackSlot $ sessionTracks session
                     in length slots == length (nub slots)

    describe "Riptide.Session definitions" $ do
        it "keeps editor code separate from applied code" $ do
            let session =
                    emptySession 4
                        & addDefinitionBlock
                            (DefinitionId "defs-a")
                            "percussion"
                            "let density = 2"
                        & editDefinitionBlock
                            (DefinitionId "defs-a")
                            "percussion"
                            "let density = 4"
            case sessionDefinitions session of
                [block] -> do
                    blockCode block `shouldBe` "let density = 4"
                    blockApplied block `shouldBe` ""
                    sessionDefinitions
                        (applyDefinitionBlock (DefinitionId "defs-a") session)
                        `shouldBe`
                            [ block
                                { blockApplied = "let density = 4"
                                }
                            ]
                _ -> expectationFailure "expected one definition block"

        it "removes one definition block while retaining siblings" $ do
            let session =
                    emptySession 4
                        & addDefinitionBlock
                            (DefinitionId "defs-a")
                            "percussion"
                            "let density = 2"
                        & addDefinitionBlock
                            (DefinitionId "defs-b")
                            "melody"
                            "let melody = \"0 2 4\""
                        & removeDefinitionBlock (DefinitionId "defs-a")

            fmap blockId (sessionDefinitions session)
                `shouldBe` [DefinitionId "defs-b"]

firstTrack :: Session -> Maybe Track
firstTrack session =
    case sessionTracks session of
        track : _ -> Just track
        [] -> Nothing

firstText :: Track -> Maybe TrackText
firstText track =
    case trackTexts track of
        text : _ -> Just text
        [] -> Nothing

hasAtMostOneActiveText :: Track -> Bool
hasAtMostOneActiveText track =
    length activeTexts <= 1
  where
    activeTexts =
        filter
            (\text -> Just (trackTextId text) == trackActiveText track)
            (trackTexts track)

trackSession :: Session
trackSession =
    case addTrack (TrackId "track-a") "track a" $ emptySession 4 of
        Just session -> session
        Nothing -> emptySession 4

addText :: Text -> Text -> Session -> Session
addText ident source =
    addTrackText (TrackId "track-a") (TextId ident) source

activate :: Text -> Session -> Session
activate ident =
    activateTrackText (TrackId "track-a") (TextId ident)

(&) :: a -> (a -> b) -> b
(&) value f = f value

data ActivationOp
    = AddText TextId Text
    | SelectText TextId
    | ActivateText TextId
    | Silence
    | RemoveText TextId
    deriving stock (Show, Eq)

genActivationSession :: Gen Session
genActivationSession = do
    ops <- listOf genActivationOp
    pure $ foldl' applyActivationOp trackSession ops

genActivationOp :: Gen ActivationOp
genActivationOp = do
    ident <- genTextId
    elements
        [ AddText ident "sound \"bd\""
        , SelectText ident
        , ActivateText ident
        , Silence
        , RemoveText ident
        ]

applyActivationOp :: Session -> ActivationOp -> Session
applyActivationOp session = \case
    AddText ident source ->
        addTrackText (TrackId "track-a") ident source session
    SelectText ident ->
        selectTrackText (TrackId "track-a") ident session
    ActivateText ident ->
        activateTrackText (TrackId "track-a") ident session
    Silence ->
        silenceTrack (TrackId "track-a") session
    RemoveText ident ->
        removeTrackText (TrackId "track-a") ident session

data SlotOp
    = AddTrack TrackId
    | RemoveTrack TrackId
    deriving stock (Show, Eq)

genSlotSession :: Gen Session
genSlotSession = do
    ops <- listOf genSlotOp
    pure $ foldl' applySlotOp (emptySession 5) ops

genSlotOp :: Gen SlotOp
genSlotOp = do
    ident <- genTrackId
    elements [AddTrack ident, RemoveTrack ident]

applySlotOp :: Session -> SlotOp -> Session
applySlotOp session = \case
    AddTrack ident ->
        case addTrack ident (trackIdText ident) session of
            Just next -> next
            Nothing -> session
    RemoveTrack ident ->
        removeTrack ident session

genTrackId :: Gen TrackId
genTrackId =
    TrackId . Text.pack . ("track-" <>) . show <$> chooseInt (1, 8)

genTextId :: Gen TextId
genTextId =
    TextId . Text.pack . ("text-" <>) . show <$> chooseInt (1, 8)

trackIdText :: TrackId -> Text
trackIdText (TrackId ident) = ident
