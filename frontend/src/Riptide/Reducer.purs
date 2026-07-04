module Riptide.Reducer
  ( DuplicateSongIds
  , DuplicateToolboxIds
  , addBlock
  , addCell
  , addTrack
  , applyAll
  , applyAutomation
  , applyBlock
  , deleteBlock
  , deleteSong
  , deleteToolbox
  , cancelConfirm
  , duplicateSong
  , duplicateToolbox
  , editBlockCode
  , editCode
  , endResizeScore
  , hush
  , moveCell
  , moveLoop
  , moveTrack
  , newSong
  , newToolbox
  , onSongName
  , onTbxName
  , openSong
  , openToolbox
  , paintEnter
  , playbackCommandsForActiveTransitions
  , removeCell
  , removeTrack
  , renameBlock
  , renameSong
  , renameToolbox
  , renameTrack
  , resizeScoreTo
  , recordBackendValidation
  , selectCell
  , setConnection
  , setBackendHost
  , setSettingsOpen
  , setWebSocket
  , setCtrl
  , setLoopEnd
  , setLoopStart
  , setPaint
  , startEdit
  , startPaint
  , startResizeScore
  , stopEdit
  , stopPaint
  , stopTrack
  , toggleCell
  , toggleEngine
  , toggleLoop
  , togglePlay
  , toggleSongRail
  , toggleToolboxRail
  ) where

import Prelude

import Data.Array as Array
import Data.FoldableWithIndex (foldlWithIndex)
import Data.Int as Int
import Data.Maybe (Maybe(..), fromMaybe)
import Riptide.Action (ControlKey(..))
import Riptide.Helpers (effectiveSelected, normalizeScore)
import Riptide.Model (App, Block, BlockId, Cell, CellId, ConnectionState, Page(..), Song, SongId, Toolbox, ToolboxId, Track, TrackId, defaultBlock, defaultCell, defaultSong, defaultToolbox, defaultTrack, totalBars)
import Riptide.Protocol.Client as Protocol
import Riptide.Validation (AuthoritativeValidation, authoritativeValidation, recordAuthoritativeValidation)
import Riptide.WebSocket (WebSocketClient)

type DuplicateSongIds =
  { songId :: SongId
  , trackIds :: Array TrackId
  , cellIds :: Array CellId
  }

type DuplicateToolboxIds =
  { toolboxId :: ToolboxId
  , blockIds :: Array BlockId
  }

toggleEngine :: App -> App
toggleEngine app =
  let
    next = not app.engine
  in
    if next then
      app { engine = true }
    else
      hush (app { engine = false })

setConnection :: ConnectionState -> App -> App
setConnection connection app =
  app { connection = connection }

setBackendHost :: String -> App -> App
setBackendHost backendHost app =
  app { backendHost = backendHost }

setSettingsOpen :: Boolean -> App -> App
setSettingsOpen settingsOpen app =
  app { settingsOpen = settingsOpen }

setWebSocket :: Maybe WebSocketClient -> App -> App
setWebSocket websocket app =
  app { websocket = websocket }

recordBackendValidation :: AuthoritativeValidation -> App -> App
recordBackendValidation result app =
  app { backendValidation = recordAuthoritativeValidation result app.backendValidation }

hush :: App -> App
hush =
  mapCurrentSongTracks \track -> track { active = Nothing }

playbackCommandsForActiveTransitions :: Array Track -> Array Track -> Array Protocol.ClientCommand
playbackCommandsForActiveTransitions before after =
  Array.mapMaybe commandFor after
  where
  commandFor track =
    let
      oldActive = activeFor track.id before
    in
      if oldActive == track.active then
        Nothing
      else
        case track.active of
          Just cellId -> Just (Protocol.ActivateTrackText track.id cellId)
          Nothing -> Just (Protocol.SilenceTrack track.id)

  activeFor trackId tracks =
    fromMaybe Nothing (_.active <$> Array.find (_.id >>> (_ == trackId)) tracks)

toggleCell :: TrackId -> CellId -> App -> App
toggleCell trackId cellId =
  mapCurrentSongTracks \track ->
    if track.id /= trackId then
      track
    else if track.active == Just cellId then
      track { active = Nothing }
    else
      track { active = Just cellId, selected = Just cellId }

stopTrack :: TrackId -> App -> App
stopTrack trackId =
  mapTrack trackId \track -> track { active = Nothing }

renameTrack :: TrackId -> String -> App -> App
renameTrack trackId name =
  mapTrack trackId \track -> track { name = name }

setCtrl :: TrackId -> ControlKey -> Int -> App -> App
setCtrl trackId key value =
  mapTrack trackId \track ->
    case key of
      Vol -> track { vol = clampInt 0 100 value }
      Flt -> track { flt = clampInt 0 100 value }
      Dly -> track { dly = clampInt 0 100 value }

editCode :: TrackId -> CellId -> String -> App -> App
editCode trackId cellId code app =
  mapTrack trackId
    ( \track ->
        let
          cells = map (\cell -> if cell.id == cellId then cell { code = code } else cell) track.cells
          active =
            if track.active == Just cellId && not (authoritativeValidation app.backendValidation code).valid then
              Nothing
            else
              track.active
        in
          track { cells = cells, active = active }
    )
    app

selectCell :: TrackId -> CellId -> App -> App
selectCell trackId cellId =
  mapTrack trackId \track ->
    if Array.any (_.id >>> (_ == cellId)) track.cells then
      track { selected = Just cellId }
    else
      track

addCell :: TrackId -> CellId -> App -> App
addCell trackId cellId =
  mapTrack trackId \track -> track { cells = track.cells <> [ defaultCell cellId ] }

addTrack :: TrackId -> App -> App
addTrack trackId =
  mapCurrentSong \song ->
    let
      n = Array.length song.tracks + 1
      hue = nextHue song.tracks
      track = (defaultTrack trackId ("track " <> show n)) { hue = hue, score = normalizeScore [] }
    in
      song { tracks = song.tracks <> [ track ] }

removeTrack :: TrackId -> App -> App
removeTrack trackId =
  armDelete ("trk:" <> trackId) (mapCurrentSong \song -> song { tracks = Array.filter (_.id >>> (_ /= trackId)) song.tracks })

removeCell :: TrackId -> CellId -> App -> App
removeCell trackId cellId =
  armDelete ("cell:" <> cellId)
    ( mapTrack trackId \track ->
        track
          { cells = Array.filter (_.id >>> (_ /= cellId)) track.cells
          , active = clearIf cellId track.active
          , selected = clearIf cellId track.selected
          }
    )

moveTrack :: TrackId -> TrackId -> App -> App
moveTrack fromTrackId toTrackId
  | fromTrackId == toTrackId = identity
  | otherwise =
      mapCurrentSong \song ->
        case Array.find (_.id >>> (_ == fromTrackId)) song.tracks of
          Just moved ->
            let
              withoutMoved = Array.filter (_.id >>> (_ /= fromTrackId)) song.tracks
            in
              if Array.any (_.id >>> (_ == toTrackId)) withoutMoved then
                song { tracks = insertBefore toTrackId moved withoutMoved }
              else
                song
          Nothing -> song

moveCell :: TrackId -> CellId -> TrackId -> Maybe CellId -> App -> App
moveCell fromTrackId cellId toTrackId maybeToCellId =
  mapCurrentSong \song ->
    if fromTrackId == toTrackId then
      song { tracks = map reorderWithin song.tracks }
    else
      case findCell fromTrackId song.tracks of
        Just moved ->
          if Array.any (_.id >>> (_ == toTrackId)) song.tracks then
            song { tracks = map (moveAcross moved) song.tracks }
          else
            song
        Nothing -> song
  where
  findCell trackId tracks =
    Array.find (_.id >>> (_ == trackId)) tracks >>= \track ->
      Array.find (_.id >>> (_ == cellId)) track.cells

  reorderWithin track
    | track.id /= fromTrackId = track
    | otherwise =
        case Array.find (_.id >>> (_ == cellId)) track.cells of
          Just moved ->
            let
              withoutMoved = Array.filter (_.id >>> (_ /= cellId)) track.cells
            in
              track { cells = insertCell maybeToCellId moved withoutMoved }
          Nothing -> track

  moveAcross moved track
    | track.id == fromTrackId =
        track
          { cells = Array.filter (_.id >>> (_ /= cellId)) track.cells
          , active = clearIf cellId track.active
          , selected = clearIf cellId track.selected
          }
    | track.id == toTrackId =
        track { cells = insertCell maybeToCellId moved track.cells }
    | otherwise = track

newSong :: SongId -> App -> App
newSong songId app =
  app
    { songs = app.songs <> [ defaultSong songId "untitled song" ]
    , currentSongId = Just songId
    , page = SongPage
    , editing = Just { kind: "song", id: songId }
    }

openSong :: SongId -> App -> App
openSong songId app =
  app { currentSongId = Just songId, page = SongPage }

renameSong :: SongId -> String -> App -> App
renameSong songId name app =
  app { songs = map (\song -> if song.id == songId then song { name = name } else song) app.songs }

onSongName :: String -> App -> App
onSongName name app =
  case app.currentSongId of
    Just songId -> renameSong songId name app
    Nothing -> app

duplicateSong :: SongId -> DuplicateSongIds -> App -> App
duplicateSong songId ids app =
  case Array.findIndex (_.id >>> (_ == songId)) app.songs of
    Just ix ->
      case Array.index app.songs ix of
        Just source ->
          let
            copy = cloneSong ids source
          in
            app
              { songs = insertAfter ix copy app.songs
              , currentSongId = Just copy.id
              , page = SongPage
              }
        Nothing -> app
    Nothing -> app

deleteSong :: SongId -> App -> App
deleteSong songId =
  armDelete ("song:" <> songId) \app ->
    let
      songs = Array.filter (_.id >>> (_ /= songId)) app.songs
      current =
        if app.currentSongId == Just songId then
          map _.id (Array.head songs)
        else
          app.currentSongId
    in
      app { songs = songs, currentSongId = current }

newToolbox :: ToolboxId -> App -> App
newToolbox toolboxId app =
  app
    { toolboxes = app.toolboxes <> [ defaultToolbox toolboxId "untitled toolbox" ]
    , currentToolboxId = Just toolboxId
    , page = DefsPage
    , editing = Just { kind: "tbx", id: toolboxId }
    }

openToolbox :: ToolboxId -> App -> App
openToolbox toolboxId app =
  app { currentToolboxId = Just toolboxId, page = DefsPage }

renameToolbox :: ToolboxId -> String -> App -> App
renameToolbox toolboxId name app =
  app { toolboxes = map (\toolbox -> if toolbox.id == toolboxId then toolbox { name = name } else toolbox) app.toolboxes }

onTbxName :: String -> App -> App
onTbxName name app =
  case app.currentToolboxId of
    Just toolboxId -> renameToolbox toolboxId name app
    Nothing -> app

duplicateToolbox :: ToolboxId -> DuplicateToolboxIds -> App -> App
duplicateToolbox toolboxId ids app =
  case Array.findIndex (_.id >>> (_ == toolboxId)) app.toolboxes of
    Just ix ->
      case Array.index app.toolboxes ix of
        Just source ->
          let
            copy = cloneToolbox ids source
          in
            app
              { toolboxes = insertAfter ix copy app.toolboxes
              , currentToolboxId = Just copy.id
              , page = DefsPage
              }
        Nothing -> app
    Nothing -> app

deleteToolbox :: ToolboxId -> App -> App
deleteToolbox toolboxId =
  armDelete ("tbx:" <> toolboxId) \app ->
    let
      toolboxes = Array.filter (_.id >>> (_ /= toolboxId)) app.toolboxes
      current =
        if app.currentToolboxId == Just toolboxId then
          map _.id (Array.head toolboxes)
        else
          app.currentToolboxId
    in
      app { toolboxes = toolboxes, currentToolboxId = current }

addBlock :: BlockId -> App -> App
addBlock blockId =
  mapCurrentToolbox \toolbox -> toolbox { blocks = toolbox.blocks <> [ defaultBlock blockId "untitled" ] }

editBlockCode :: BlockId -> String -> App -> App
editBlockCode blockId code =
  mapBlock blockId \block -> block { code = code }

renameBlock :: BlockId -> String -> App -> App
renameBlock blockId name =
  mapBlock blockId \block -> block { name = name }

applyBlock :: BlockId -> App -> App
applyBlock blockId =
  \app ->
    mapBlock blockId
      ( \block ->
          if (authoritativeValidation app.backendValidation block.code).valid then
            block { applied = block.code }
          else
            block
      )
      app

applyAll :: App -> App
applyAll app =
  mapCurrentToolbox
    ( \toolbox ->
        toolbox
          { blocks =
              map
                ( \block ->
                    if (authoritativeValidation app.backendValidation block.code).valid then block { applied = block.code } else block
                )
                toolbox.blocks
          }
    )
    app

deleteBlock :: BlockId -> App -> App
deleteBlock blockId =
  armDelete ("blk:" <> blockId)
    (mapCurrentToolbox \toolbox -> toolbox { blocks = Array.filter (_.id >>> (_ /= blockId)) toolbox.blocks })

toggleSongRail :: App -> App
toggleSongRail app =
  app { songRailOpen = not app.songRailOpen }

toggleToolboxRail :: App -> App
toggleToolboxRail app =
  app { toolboxRailOpen = not app.toolboxRailOpen }

startEdit :: String -> String -> App -> App
startEdit kind id app =
  app { editing = Just { kind, id } }

stopEdit :: App -> App
stopEdit app =
  app { editing = Nothing }

startResizeScore :: App -> App
startResizeScore app =
  app { resizing = true, confirm = Nothing }

resizeScoreTo :: Int -> Int -> App -> App
resizeScoreTo innerHeight height app =
  app { scoreHeight = clampInt 96 (innerHeight - 200) height }

endResizeScore :: App -> App
endResizeScore app =
  app { resizing = false }

cancelConfirm :: App -> App
cancelConfirm app =
  app { confirm = Nothing }

setPaint :: TrackId -> Int -> Boolean -> App -> App
setPaint trackId bar value =
  mapTrack trackId \track ->
    track { score = setScoreAt bar value track.score }

startPaint :: TrackId -> Int -> App -> App
startPaint trackId bar app =
  let
    value = not (scoreAt trackId bar app)
  in
    (setPaint trackId bar value app) { paint = Just { trackId, bar, paintVal: value }, confirm = Nothing }

paintEnter :: TrackId -> Int -> App -> App
paintEnter trackId bar app =
  case app.paint of
    Just paint -> setPaint trackId bar paint.paintVal app
    Nothing -> app

stopPaint :: App -> App
stopPaint app =
  app { paint = Nothing }

applyAutomation :: Int -> App -> App
applyAutomation bar app =
  mapCurrentSongTracks
    ( \track ->
        automateTrack track
    )
    app
  where
  automateTrack track =
    if not (Array.any identity track.score) then
      track
    else if fromMaybe false (Array.index track.score bar) then
      case effectiveSelected track of
        Just cell
          | app.engine && (authoritativeValidation app.backendValidation cell.code).valid -> track { active = Just cell.id }
        _ -> track { active = Nothing }
    else
      track { active = Nothing }

togglePlay :: App -> App
togglePlay app =
  let
    next = app { playing = not app.playing }
  in
    if next.playing then applyAutomation (Int.floor next.playhead) next else next

toggleLoop :: App -> App
toggleLoop app =
  app { loopOn = not app.loopOn }

setLoopStart :: Int -> App -> App
setLoopStart raw app =
  let
    start = clampInt 0 (app.loopEnd - 1) raw
  in
    app { loopStart = start, playhead = snapPlayhead start app.loopEnd app.playhead }

setLoopEnd :: Int -> App -> App
setLoopEnd raw app =
  let
    end = clampInt (app.loopStart + 1) totalBars raw
  in
    app { loopEnd = end, playhead = snapPlayhead app.loopStart end app.playhead }

moveLoop :: Int -> App -> App
moveLoop delta app =
  let
    len = app.loopEnd - app.loopStart
    start = clampInt 0 (totalBars - len) (app.loopStart + delta)
    end = start + len
  in
    app { loopStart = start, loopEnd = end, playhead = snapPlayhead start end app.playhead }

armDelete :: String -> (App -> App) -> App -> App
armDelete key action app =
  if app.confirm == Just key then
    (action app) { confirm = Nothing }
  else
    app { confirm = Just key, confirmToken = app.confirmToken + 1 }

mapCurrentSongTracks :: (Track -> Track) -> App -> App
mapCurrentSongTracks f =
  mapCurrentSong \song -> song { tracks = map f song.tracks }

mapTrack :: TrackId -> (Track -> Track) -> App -> App
mapTrack trackId f =
  mapCurrentSongTracks \track -> if track.id == trackId then f track else track

mapCurrentSong :: (Song -> Song) -> App -> App
mapCurrentSong f app =
  case app.currentSongId of
    Just songId -> app { songs = map (\song -> if song.id == songId then f song else song) app.songs }
    Nothing -> app

mapCurrentToolbox :: (Toolbox -> Toolbox) -> App -> App
mapCurrentToolbox f app =
  case app.currentToolboxId of
    Just toolboxId -> app { toolboxes = map (\toolbox -> if toolbox.id == toolboxId then f toolbox else toolbox) app.toolboxes }
    Nothing -> app

mapBlock :: BlockId -> (Block -> Block) -> App -> App
mapBlock blockId f =
  mapCurrentToolbox \toolbox -> toolbox { blocks = map (\block -> if block.id == blockId then f block else block) toolbox.blocks }

cloneSong :: DuplicateSongIds -> Song -> Song
cloneSong ids source =
  let
    built = foldlWithIndex cloneTrack { tracks: [], nextCell: 0 } source.tracks
  in
    { id: ids.songId
    , name: source.name <> " copy"
    , tracks: built.tracks
    }
  where
  cloneTrack ix acc track =
    let
      cellMap = Array.mapWithIndex (\cellIx cell -> { old: cell.id, new: idAt "cell-copy-" (acc.nextCell + cellIx) ids.cellIds }) track.cells
      cells = map (\pair -> { id: pair.new, code: (cellById pair.old track).code }) cellMap
      copy =
        track
          { id = idAt "track-copy-" ix ids.trackIds
          , active = remapMaybe cellMap track.active
          , selected = remapMaybe cellMap track.selected
          , score = normalizeScore track.score
          , cells = cells
          }
    in
      { tracks: acc.tracks <> [ copy ], nextCell: acc.nextCell + Array.length track.cells }

cloneToolbox :: DuplicateToolboxIds -> Toolbox -> Toolbox
cloneToolbox ids source =
  { id: ids.toolboxId
  , name: source.name <> " copy"
  , blocks:
      Array.mapWithIndex
        ( \ix block ->
            block { id = idAt "block-copy-" ix ids.blockIds }
        )
        source.blocks
  }

cellById :: CellId -> Track -> { id :: CellId, code :: String }
cellById cellId track =
  fromMaybe (defaultCell cellId) (Array.find (_.id >>> (_ == cellId)) track.cells)

remapMaybe :: Array { old :: String, new :: String } -> Maybe String -> Maybe String
remapMaybe mapping value =
  value >>= \old -> map _.new (Array.find (_.old >>> (_ == old)) mapping)

clearIf :: String -> Maybe String -> Maybe String
clearIf id value =
  if value == Just id then Nothing else value

insertAfter :: forall a. Int -> a -> Array a -> Array a
insertAfter ix value xs =
  Array.take (ix + 1) xs <> [ value ] <> Array.drop (ix + 1) xs

insertBefore :: forall r. String -> { id :: String | r } -> Array { id :: String | r } -> Array { id :: String | r }
insertBefore id value xs =
  case Array.findIndex (_.id >>> (_ == id)) xs of
    Just ix -> Array.take ix xs <> [ value ] <> Array.drop ix xs
    Nothing -> xs <> [ value ]

insertCell :: Maybe CellId -> Cell -> Array Cell -> Array Cell
insertCell maybeCellId cell cells =
  case maybeCellId of
    Just toCellId -> insertBefore toCellId cell cells
    Nothing -> cells <> [ cell ]

nextHue :: Array Track -> Int
nextHue tracks =
  fromMaybe 200 (Array.find (\hue -> not (Array.any (_.hue >>> (_ == hue)) tracks)) huePalette)

huePalette :: Array Int
huePalette =
  [ 25, 95, 200, 285, 330, 55, 155, 250 ]

setScoreAt :: Int -> Boolean -> Array Boolean -> Array Boolean
setScoreAt bar value score =
  Array.mapWithIndex (\ix old -> if ix == bar then value else old) (normalizeScore score)

scoreAt :: TrackId -> Int -> App -> Boolean
scoreAt trackId bar app =
  fromMaybe false do
    songId <- app.currentSongId
    song <- Array.find (_.id >>> (_ == songId)) app.songs
    track <- Array.find (_.id >>> (_ == trackId)) song.tracks
    Array.index (normalizeScore track.score) bar

snapPlayhead :: Int -> Int -> Number -> Number
snapPlayhead start end playhead
  | playhead < Int.toNumber start = Int.toNumber start
  | playhead >= Int.toNumber end = Int.toNumber end - 0.001
  | otherwise = playhead

clampInt :: Int -> Int -> Int -> Int
clampInt lo hi value =
  max lo (min hi value)

idAt :: String -> Int -> Array String -> String
idAt prefix ix ids =
  fromMaybe (prefix <> show (ix + 1)) (Array.index ids ix)
