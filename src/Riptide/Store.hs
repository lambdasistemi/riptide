module Riptide.Store
    ( loadDefinitions
    , loadSession
    , loadTracks
    , saveDefinitions
    , saveSession
    , saveTracks
    ) where

{- |
Module      : Riptide.Store
Description : JSON persistence shell for riptide sessions.
Copyright   : (c) Paolo Veronelli, 2026
License     : BSD-3-Clause

This module contains the impure persistence boundary for backend session state.
Tracks and definition blocks are stored independently under a caller-provided
state directory.
-}

import Data.Aeson
    ( FromJSON
    , ToJSON
    , eitherDecodeFileStrict
    , encodeFile
    )
import Riptide.Session
    ( DefinitionBlock
    , Session (..)
    , Track
    )
import System.Directory
    ( createDirectoryIfMissing
    , doesFileExist
    )
import System.FilePath
    ( takeDirectory
    , (</>)
    )

-- | Save only track state to the state directory.
saveTracks :: FilePath -> [Track] -> IO ()
saveTracks stateDir =
    saveStore (tracksPath stateDir)

-- | Load only track state from the state directory.
loadTracks :: FilePath -> IO [Track]
loadTracks stateDir =
    loadStore (tracksPath stateDir)

-- | Save only definition block state to the state directory.
saveDefinitions :: FilePath -> [DefinitionBlock] -> IO ()
saveDefinitions stateDir =
    saveStore (definitionsPath stateDir)

-- | Load only definition block state from the state directory.
loadDefinitions :: FilePath -> IO [DefinitionBlock]
loadDefinitions stateDir =
    loadStore (definitionsPath stateDir)

-- | Save a full session to separate track and definition stores.
saveSession :: FilePath -> Session -> IO ()
saveSession stateDir session = do
    saveDefinitions stateDir (sessionDefinitions session)
    saveTracks stateDir (sessionTracks session)

-- | Load a full session, reading definitions before tracks.
loadSession :: Int -> FilePath -> IO Session
loadSession slotCapacity stateDir = do
    definitions <- loadDefinitions stateDir
    tracks <- loadTracks stateDir
    pure
        Session
            { sessionSlotCapacity = max 0 slotCapacity
            , sessionTracks = tracks
            , sessionDefinitions = definitions
            }

saveStore :: ToJSON a => FilePath -> a -> IO ()
saveStore path value = do
    createDirectoryIfMissing True $ storeDirectory path
    encodeFile path value

loadStore :: FromJSON a => FilePath -> IO [a]
loadStore path = do
    exists <- doesFileExist path
    if exists
        then
            either fail pure =<< eitherDecodeFileStrict path
        else pure []

tracksPath :: FilePath -> FilePath
tracksPath stateDir =
    stateDir </> "tracks.json"

definitionsPath :: FilePath -> FilePath
definitionsPath stateDir =
    stateDir </> "definitions.json"

storeDirectory :: FilePath -> FilePath
storeDirectory path =
    case takeDirectory path of
        "" -> "."
        directory -> directory
