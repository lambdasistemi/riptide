module Riptide.View.Files
  ( FileResult
  , downloadSongJson
  , downloadToolboxJson
  , parseSongFile
  , parseToolboxFile
  , pickTextFileEmitter
  , timeoutEmitter
  ) where

import Prelude

import Effect (Effect)
import Halogen.Subscription as HS
import Riptide.ImportExport (ExportedSong, ExportedToolbox)

type FileResult =
  { ok :: Boolean
  , value :: String
  }

pickTextFileEmitter :: forall action. (FileResult -> action) -> HS.Emitter action
pickTextFileEmitter toAction =
  map toAction (HS.makeEmitter pickTextFile)

timeoutEmitter :: forall action. Int -> action -> HS.Emitter action
timeoutEmitter ms action =
  HS.makeEmitter (timeout ms action)

foreign import downloadSongJson :: String -> ExportedSong -> Effect Unit

foreign import downloadToolboxJson :: String -> ExportedToolbox -> Effect Unit

foreign import parseSongFile :: String -> Array ExportedSong

foreign import parseToolboxFile :: String -> Array ExportedToolbox

foreign import pickTextFile :: (FileResult -> Effect Unit) -> Effect (Effect Unit)

foreign import timeout :: forall action. Int -> action -> (action -> Effect Unit) -> Effect (Effect Unit)
