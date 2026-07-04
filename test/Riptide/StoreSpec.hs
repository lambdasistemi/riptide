module Riptide.StoreSpec
    ( spec
    ) where

import Control.Exception (bracket)
import Control.Monad (forM)
import Data.List (isInfixOf)
import Data.Text (Text)
import Data.Text qualified as Text
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
import Riptide.Store
    ( loadDefinitions
    , loadSession
    , loadTracks
    , saveDefinitions
    , saveSession
    , saveTracks
    )
import System.Directory
    ( createDirectoryIfMissing
    , doesFileExist
    , getTemporaryDirectory
    , removeFile
    , removePathForcibly
    )
import System.FilePath ((</>))
import System.IO (hClose, openTempFile)
import Test.Hspec
    ( Spec
    , describe
    , it
    , shouldReturn
    , shouldSatisfy
    )
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck
    ( Gen
    , chooseInt
    , elements
    , forAll
    , ioProperty
    , sublistOf
    )

spec :: Spec
spec =
    describe "Riptide.Store" $ do
        it "saves tracks and definitions to separate JSON files" $
            withTempDir $ \dir -> do
                saveTracks dir (sessionTracks exampleSession)
                saveDefinitions dir (sessionDefinitions exampleSession)

                doesFileExist (dir </> "tracks.json") `shouldReturn` True
                doesFileExist (dir </> "definitions.json")
                    `shouldReturn` True

        it "loads missing store files as empty collections" $
            withTempDir $ \dir -> do
                loadTracks dir `shouldReturn` []
                loadDefinitions dir `shouldReturn` []
                loadSession 8 dir `shouldReturn` emptyStoreSession 8

        it "loads definitions before tracks when assembling a session" $ do
            source <- readFile "src/Riptide/Store.hs"
            source `shouldSatisfy` loadsDefinitionsBeforeTracks

        prop
            "round-trips generated session tracks and definitions"
            $ forAll genSession
            $ \session ->
                ioProperty $
                    withTempDir $ \dir -> do
                        saveSession dir session
                        loaded <- loadSession (sessionSlotCapacity session) dir
                        pure $
                            sessionTracks loaded == sessionTracks session
                                && sessionDefinitions loaded
                                    == sessionDefinitions session

exampleSession :: Session
exampleSession =
    Session
        { sessionSlotCapacity = 4
        , sessionTracks =
            [ Track
                { trackId = TrackId "track-a"
                , trackName = "drums"
                , trackSlot = Slot 1
                , trackTexts =
                    [ TrackText
                        { trackTextId = TextId "text-a"
                        , trackTextSource = "sound \"bd\""
                        }
                    ]
                , trackActiveText = Just $ TextId "text-a"
                , trackSelectedText = Just $ TextId "text-a"
                }
            ]
        , sessionDefinitions =
            [ DefinitionBlock
                { blockId = DefinitionId "defs-a"
                , blockName = "shared"
                , blockCode = "let pat = \"0 3\""
                , blockApplied = "let pat = \"0 3\""
                }
            ]
        }

emptyStoreSession :: Int -> Session
emptyStoreSession slotCapacity =
    Session
        { sessionSlotCapacity = slotCapacity
        , sessionTracks = []
        , sessionDefinitions = []
        }

loadsDefinitionsBeforeTracks :: String -> Bool
loadsDefinitionsBeforeTracks source =
    case (findIndexText definitionsLine, findIndexText tracksLine) of
        (Just definitionsIndex, Just tracksIndex) ->
            definitionsIndex < tracksIndex
        _ -> False
  where
    definitionsLine = "definitions <- loadDefinitions"
    tracksLine = "tracks <- loadTracks"
    findIndexText needle =
        lookup True $
            zip
                ((needle `isInfixOf`) <$> lines source)
                [0 :: Int ..]

withTempDir :: (FilePath -> IO a) -> IO a
withTempDir =
    bracket acquire removePathForcibly
  where
    acquire = do
        tmp <- getTemporaryDirectory
        (path, handle) <- openTempFile tmp "riptide-store"
        hClose handle
        removeFile path
        createDirectoryIfMissing True path
        pure path

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
    forM [1 .. count] $ \index -> do
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
    forM [1 .. count] $ \index ->
        pure
            TrackText
                { trackTextId =
                    TextId $
                        numberedText
                            ("text-" <> show trackIndex)
                            index
                , trackTextSource =
                    "sound \""
                        <> numberedText "bd" index
                        <> "\""
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
    forM [1 .. count] $ \index ->
        pure
            DefinitionBlock
                { blockId = DefinitionId $ numberedText "defs" index
                , blockName = numberedText "Definition" index
                , blockCode = "let density = " <> numberedText "" index
                , blockApplied =
                    "let density = " <> numberedText "" (index + 1)
                }

numberedText :: String -> Int -> Text
numberedText prefix index =
    Text.pack $ prefix <> "-" <> show index
