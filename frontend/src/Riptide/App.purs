module Riptide.App
  ( commandsForSocketOpen
  , component
  , sessionFromApp
  ) where

import Prelude

import Data.Array as Array
import Data.Foldable (traverse_)
import Data.Int as Int
import Data.Maybe (Maybe(..))
import Data.Traversable (traverse)
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Riptide.Action (ControlKey)
import Riptide.ImportExport as ImportExport
import Riptide.Model (App, Block, BlockId, Cell, CellId, ConnectionState(..), DropTarget, Page(..), Song, SongId, Toolbox, ToolboxId, Track, TrackId, canUseBackend, totalBars)
import Riptide.Protocol.Client as Protocol
import Riptide.Reducer as Reducer
import Riptide.Validation (authoritativeValidation)
import Riptide.View.Definitions as Definitions
import Riptide.View.Files as Files
import Riptide.View.Id (mintId)
import Riptide.View.Playhead as Playhead
import Riptide.View.Seed (seedApp)
import Riptide.View.Shell as Shell
import Riptide.View.Song as Song
import Riptide.WebSocket as WebSocket
import Web.Event.Event as Event
import Web.HTML.Event.DragEvent (DragEvent)
import Web.HTML.Event.DragEvent as DragEvent
import Web.UIEvent.KeyboardEvent (KeyboardEvent)
import Web.UIEvent.KeyboardEvent as KeyboardEvent
import Web.UIEvent.MouseEvent (MouseEvent)
import Web.UIEvent.MouseEvent as MouseEvent

data Action
  = Initialize
  | CancelConfirm
  | CancelConfirmClick MouseEvent
  | ConfirmTimeout H.SubscriptionId String Int
  | ShellKeyDown KeyboardEvent
  | GoSong
  | GoDefs
  | ToggleEngine
  | ToggleSettings
  | SetBackendHost String
  | Hush
  | NewSong
  | NewToolbox
  | ExportSong
  | ImportSong
  | ExportToolbox
  | ImportToolbox
  | SongFilePicked H.SubscriptionId Files.FileResult
  | ToolboxFilePicked H.SubscriptionId Files.FileResult
  | ClearToast H.SubscriptionId String
  | OpenSong SongId
  | OpenToolbox ToolboxId
  | RenameSong SongId String
  | RenameToolbox ToolboxId String
  | DuplicateSong SongId
  | DuplicateToolbox ToolboxId
  | DeleteSong SongId MouseEvent
  | DeleteToolbox ToolboxId MouseEvent
  | AddBlock
  | RenameBlock BlockId String
  | EditBlockCode BlockId String
  | ApplyBlock BlockId
  | ApplyAll
  | DeleteBlock BlockId MouseEvent
  | RenameTrack TrackId String
  | SetCtrl TrackId ControlKey String
  | StopTrack TrackId
  | AddTrack
  | DeleteTrack TrackId MouseEvent
  | AddCell TrackId
  | SelectCell TrackId CellId
  | ToggleCell TrackId CellId
  | EditCode TrackId CellId String
  | DeleteCell TrackId CellId MouseEvent
  | StartEdit String String
  | StopEdit
  | FocusCell CellId
  | BlurCell CellId
  | StartPaint TrackId Int
  | PaintEnter TrackId Int
  | StopPaint
  | StartTrackDrag TrackId
  | StartCellDrag TrackId CellId
  | DragOver DropTarget DragEvent
  | DropOn DropTarget DragEvent
  | EndDrag
  | TogglePlay
  | ToggleLoop
  | SetLoopStart String
  | SetLoopEnd String
  | MoveLoop Int
  | PlayheadTick H.SubscriptionId Number
  | SocketEvent Int H.SubscriptionId WebSocket.WebSocketEvent

component :: forall query input output m. MonadAff m => H.Component query input output m
component =
  H.mkComponent
    { initialState: const seedApp
    , render
    , eval: H.mkEval H.defaultEval { handleAction = handleAction, initialize = Just Initialize }
    }

render :: forall slots m. App -> H.ComponentHTML Action slots m
render app =
  Shell.render shellActions app
    case app.page of
      SongPage -> Song.render songActions app
      DefsPage -> Definitions.render definitionsActions app

shellActions :: Shell.ShellActions Action
shellActions =
  { goSong: GoSong
  , goDefs: GoDefs
  , toggleEngine: ToggleEngine
  , toggleSettings: ToggleSettings
  , setBackendHost: SetBackendHost
  , hush: Hush
  , newSong: NewSong
  , newToolbox: NewToolbox
  , exportSong: ExportSong
  , importSong: ImportSong
  , exportToolbox: ExportToolbox
  , importToolbox: ImportToolbox
  , cancelConfirm: CancelConfirm
  , keyDown: ShellKeyDown
  }

songActions :: Song.SongActions Action
songActions =
  { newSong: NewSong
  , openSong: OpenSong
  , renameSong: RenameSong
  , duplicateSong: DuplicateSong
  , deleteSong: DeleteSong
  , cancelConfirm: CancelConfirmClick
  , renameTrack: RenameTrack
  , setCtrl: SetCtrl
  , stopTrack: StopTrack
  , addTrack: AddTrack
  , deleteTrack: DeleteTrack
  , addCell: AddCell
  , selectCell: SelectCell
  , toggleCell: ToggleCell
  , editCode: EditCode
  , deleteCell: DeleteCell
  , startEdit: StartEdit
  , stopEdit: StopEdit
  , focusCell: FocusCell
  , blurCell: BlurCell
  , startPaint: StartPaint
  , paintEnter: PaintEnter
  , stopPaint: StopPaint
  , startTrackDrag: StartTrackDrag
  , startCellDrag: StartCellDrag
  , dragOver: DragOver
  , dropOn: DropOn
  , endDrag: EndDrag
  , togglePlay: TogglePlay
  , toggleLoop: ToggleLoop
  , setLoopStart: SetLoopStart
  , setLoopEnd: SetLoopEnd
  , moveLoop: MoveLoop
  }

definitionsActions :: Definitions.DefinitionsActions Action
definitionsActions =
  { newToolbox: NewToolbox
  , openToolbox: OpenToolbox
  , renameToolbox: RenameToolbox
  , duplicateToolbox: DuplicateToolbox
  , deleteToolbox: DeleteToolbox
  , cancelConfirm: CancelConfirmClick
  , addBlock: AddBlock
  , renameBlock: RenameBlock
  , editBlockCode: EditBlockCode
  , applyBlock: ApplyBlock
  , applyAll: ApplyAll
  , deleteBlock: DeleteBlock
  , startEdit: StartEdit
  , stopEdit: StopEdit
  }

handleAction :: forall output m. MonadAff m => Action -> H.HalogenM App Action () output m Unit
handleAction = case _ of
  Initialize -> do
    backendHost <- H.liftEffect WebSocket.loadBackendHost
    H.modify_ (Reducer.setBackendHost backendHost)
    app <- H.get
    when app.engine do
      H.modify_ (Reducer.setConnection Connecting)
      subscribeWebSocket
    when app.playing startPlayhead
  CancelConfirm ->
    H.modify_ Reducer.cancelConfirm
  CancelConfirmClick event -> do
    stopMouseEvent event
    H.modify_ Reducer.cancelConfirm
  ConfirmTimeout subscriptionId key token -> do
    H.unsubscribe subscriptionId
    H.modify_ \app ->
      if app.confirm == Just key && app.confirmToken == token then
        Reducer.cancelConfirm app
      else
        app
  ShellKeyDown event ->
    when (KeyboardEvent.key event == "Escape") do
      H.liftEffect (Event.preventDefault (KeyboardEvent.toEvent event))
      H.modify_ Reducer.cancelConfirm
  GoSong ->
    H.modify_ \app ->
      case app.currentSongId of
        Just songId -> Reducer.openSong songId app
        Nothing -> app { page = SongPage }
  GoDefs ->
    H.modify_ \app ->
      case app.currentToolboxId of
        Just toolboxId -> Reducer.openToolbox toolboxId app
        Nothing -> app { page = DefsPage }
  ToggleEngine -> do
    app <- H.get
    case app.connection of
      Connected -> do
        let silenced = Reducer.hush app
        sendPlaybackTransitions app silenced
        traverse_ (H.liftEffect <<< WebSocket.close) app.websocket
        H.put (silenced { websocket = Nothing, websocketGeneration = silenced.websocketGeneration + 1, connection = Disconnected })
      Disconnected -> do
        H.modify_ \state -> Reducer.setConnection Connecting (state { websocketGeneration = state.websocketGeneration + 1 })
        subscribeWebSocket
      ConnectionError _ -> do
        H.modify_ \state -> Reducer.setConnection Connecting (state { websocketGeneration = state.websocketGeneration + 1 })
        subscribeWebSocket
      Connecting ->
        pure unit
  ToggleSettings ->
    H.modify_ \app -> Reducer.setSettingsOpen (not app.settingsOpen) app
  SetBackendHost backendHost -> do
    app <- H.get
    when (backendHost /= app.backendHost) do
      H.liftEffect (WebSocket.saveBackendHost backendHost)
      traverse_ (H.liftEffect <<< WebSocket.close) app.websocket
      let
        reconnect =
          case app.connection of
            Disconnected -> false
            _ -> app.engine
        nextGeneration = app.websocketGeneration + 1
      H.modify_ \state ->
        state
          { backendHost = backendHost
          , websocket = Nothing
          , websocketGeneration = nextGeneration
          , connection = if reconnect then Connecting else state.connection
          }
      when reconnect subscribeWebSocket
  Hush -> do
    before <- H.get
    let after = Reducer.hush before
    H.put after
    sendPlaybackTransitions before after
  NewSong -> do
    songId <- H.liftEffect (mintId "s")
    H.modify_ (Reducer.newSong songId)
  NewToolbox -> do
    toolboxId <- H.liftEffect (mintId "tb")
    H.modify_ (Reducer.newToolbox toolboxId)
  ExportSong -> do
    app <- H.get
    case app.currentSongId >>= \songId -> songById songId app of
      Just song -> do
        H.liftEffect (Files.downloadSongJson (fileName song.name "song") (ImportExport.exportSong song))
        showToast ("Exported song " <> song.name)
      Nothing ->
        showToast "No current song to export"
  ImportSong ->
    H.subscribe' \subscriptionId -> Files.pickTextFileEmitter (SongFilePicked subscriptionId)
  ExportToolbox -> do
    app <- H.get
    case app.currentToolboxId >>= \toolboxId -> toolboxById toolboxId app of
      Just toolbox -> do
        H.liftEffect (Files.downloadToolboxJson (fileName toolbox.name "toolbox") (ImportExport.exportToolbox toolbox))
        showToast ("Exported toolbox " <> toolbox.name)
      Nothing ->
        showToast "No current toolbox to export"
  ImportToolbox ->
    H.subscribe' \subscriptionId -> Files.pickTextFileEmitter (ToolboxFilePicked subscriptionId)
  SongFilePicked subscriptionId result -> do
    H.unsubscribe subscriptionId
    if result.ok then
      case Array.index (Files.parseSongFile result.value) 0 of
        Just exported -> do
          songId <- H.liftEffect (mintId "s")
          trackIds <- traverse (const (H.liftEffect (mintId "t"))) exported.tracks
          cellIds <- traverse (const (H.liftEffect (mintId "c"))) (Array.concatMap _.cells exported.tracks)
          H.modify_ (ImportExport.importSong songId trackIds cellIds exported)
          showToast ("Imported song " <> exported.name)
        Nothing ->
          showToast "Could not import song JSON"
    else
      showToast result.value
  ToolboxFilePicked subscriptionId result -> do
    H.unsubscribe subscriptionId
    if result.ok then
      case Array.index (Files.parseToolboxFile result.value) 0 of
        Just exported -> do
          toolboxId <- H.liftEffect (mintId "tb")
          blockIds <- traverse (const (H.liftEffect (mintId "b"))) exported.blocks
          H.modify_ (ImportExport.importToolbox toolboxId blockIds exported)
          showToast ("Imported toolbox " <> exported.name)
        Nothing ->
          showToast "Could not import toolbox JSON"
    else
      showToast result.value
  ClearToast subscriptionId message -> do
    H.unsubscribe subscriptionId
    H.modify_ \app -> if app.toast == Just message then app { toast = Nothing } else app
  OpenSong songId ->
    H.modify_ (Reducer.openSong songId)
  OpenToolbox toolboxId ->
    H.modify_ (Reducer.openToolbox toolboxId)
  RenameSong songId name ->
    H.modify_ (Reducer.renameSong songId name)
  RenameToolbox toolboxId name ->
    H.modify_ (Reducer.renameToolbox toolboxId name)
  DuplicateSong songId -> do
    app <- H.get
    case songById songId app of
      Just source -> do
        newSongId <- H.liftEffect (mintId "s")
        trackIds <- traverse (const (H.liftEffect (mintId "t"))) source.tracks
        cellIds <- traverse (const (H.liftEffect (mintId "c"))) (Array.concatMap _.cells source.tracks)
        H.modify_ (Reducer.duplicateSong songId { songId: newSongId, trackIds, cellIds })
      Nothing ->
        pure unit
  DuplicateToolbox toolboxId -> do
    app <- H.get
    case toolboxById toolboxId app of
      Just source -> do
        newToolboxId <- H.liftEffect (mintId "tb")
        blockIds <- traverse (const (H.liftEffect (mintId "b"))) source.blocks
        H.modify_ (Reducer.duplicateToolbox toolboxId { toolboxId: newToolboxId, blockIds })
      Nothing ->
        pure unit
  DeleteSong songId event ->
    applyDelete event (Reducer.deleteSong songId)
  DeleteToolbox toolboxId event ->
    applyDelete event (Reducer.deleteToolbox toolboxId)
  AddBlock -> do
    blockId <- H.liftEffect (mintId "b")
    H.modify_ (Reducer.addBlock blockId)
  RenameBlock blockId name -> do
    H.modify_ (Reducer.renameBlock blockId name)
    app <- H.get
    case blockById blockId app of
      Just block -> sendWhenConnected (Protocol.SaveDefinition block.id block.name block.code)
      Nothing -> pure unit
  EditBlockCode blockId code -> do
    H.modify_ (Reducer.editBlockCode blockId code)
    app <- H.get
    case blockById blockId app of
      Just block -> do
        sendWhenConnected (Protocol.SaveDefinition block.id block.name block.code)
        sendWhenConnected (Protocol.ValidateText block.code)
      Nothing -> pure unit
  ApplyBlock blockId -> do
    H.modify_ (Reducer.applyBlock blockId)
    app <- H.get
    case blockById blockId app of
      Just block -> sendDefinitionAndApply block
      Nothing -> pure unit
  ApplyAll -> do
    H.modify_ Reducer.applyAll
    app <- H.get
    traverse_ sendDefinitionAndApply (currentBlocks app)
  DeleteBlock blockId event ->
    applyDelete event (Reducer.deleteBlock blockId)
  RenameTrack trackId name ->
    H.modify_ (Reducer.renameTrack trackId name)
  SetCtrl trackId key raw ->
    case Int.fromString raw of
      Just value -> H.modify_ (Reducer.setCtrl trackId key value)
      Nothing -> pure unit
  StopTrack trackId -> do
    before <- H.get
    let after = Reducer.stopTrack trackId before
    H.put after
    sendPlaybackTransitions before after
  AddTrack -> do
    trackId <- H.liftEffect (mintId "t")
    H.modify_ (Reducer.addTrack trackId)
  DeleteTrack trackId event ->
    applyDelete event (Reducer.removeTrack trackId)
  AddCell trackId -> do
    cellId <- H.liftEffect (mintId "c")
    H.modify_ (Reducer.addCell trackId cellId)
  SelectCell trackId cellId ->
    H.modify_ (Reducer.selectCell trackId cellId)
  ToggleCell trackId cellId -> do
    before <- H.get
    if before.engine && (cellIsLaunchable trackId cellId before || cellIsActive trackId cellId before) then do
      let after = Reducer.toggleCell trackId cellId before
      H.put after
      sendPlaybackTransitions before after
    else
      pure unit
  EditCode trackId cellId code -> do
    H.modify_ (Reducer.editCode trackId cellId code)
    sendWhenConnected (Protocol.SaveTrackText trackId cellId code)
    sendWhenConnected (Protocol.ValidateText code)
  DeleteCell trackId cellId event ->
    applyDelete event (Reducer.removeCell trackId cellId)
  StartEdit kind id ->
    H.modify_ (Reducer.startEdit kind id)
  StopEdit ->
    H.modify_ Reducer.stopEdit
  FocusCell cellId ->
    H.modify_ \app -> app { focusCell = Just cellId }
  BlurCell cellId ->
    H.modify_ \app ->
      if app.focusCell == Just cellId then app { focusCell = Nothing } else app
  StartPaint trackId bar ->
    H.modify_ (Reducer.startPaint trackId bar)
  PaintEnter trackId bar ->
    H.modify_ (Reducer.paintEnter trackId bar)
  StopPaint ->
    H.modify_ Reducer.stopPaint
  StartTrackDrag trackId ->
    H.modify_ \app ->
      app
        { drag = Just { kind: "track", trackId, cellId: Nothing }
        , over = Nothing
        , confirm = Nothing
        }
  StartCellDrag trackId cellId ->
    H.modify_ \app ->
      app
        { drag = Just { kind: "cell", trackId, cellId: Just cellId }
        , over = Nothing
        , confirm = Nothing
        }
  DragOver target event -> do
    H.liftEffect (Event.preventDefault (DragEvent.toEvent event))
    H.liftEffect (Event.stopPropagation (DragEvent.toEvent event))
    H.modify_ \app ->
      if acceptsDrop target app then app { over = Just target } else app { over = Nothing }
  DropOn target event -> do
    H.liftEffect (Event.preventDefault (DragEvent.toEvent event))
    H.liftEffect (Event.stopPropagation (DragEvent.toEvent event))
    H.modify_ (clearDrag <<< applyDrop target)
  EndDrag ->
    H.modify_ clearDrag
  TogglePlay -> do
    before <- H.get
    let after = Reducer.togglePlay before
    H.put after
    sendPlaybackTransitions before after
    when after.playing startPlayhead
  ToggleLoop ->
    H.modify_ Reducer.toggleLoop
  SetLoopStart raw ->
    case Int.fromString raw of
      Just value -> H.modify_ (Reducer.setLoopStart value)
      Nothing -> pure unit
  SetLoopEnd raw ->
    case Int.fromString raw of
      Just value -> H.modify_ (Reducer.setLoopEnd value)
      Nothing -> pure unit
  MoveLoop delta ->
    H.modify_ (Reducer.moveLoop delta)
  PlayheadTick subscriptionId dt -> do
    app <- H.get
    if app.playing then do
      let after = advancePlayhead dt app
      H.put after
      sendPlaybackTransitions app after
    else
      H.unsubscribe subscriptionId
  SocketEvent generation subscriptionId event ->
    handleSocketEvent generation subscriptionId event

startPlayhead :: forall output m. MonadAff m => H.HalogenM App Action () output m Unit
startPlayhead =
  H.subscribe' \subscriptionId ->
    Playhead.animationFrameEmitter (PlayheadTick subscriptionId)

subscribeWebSocket :: forall output m. MonadAff m => H.HalogenM App Action () output m Unit
subscribeWebSocket = do
  app <- H.get
  H.subscribe' \subscriptionId ->
    WebSocket.connectEmitter app.backendHost (SocketEvent app.websocketGeneration subscriptionId)

advancePlayhead :: Number -> App -> App
advancePlayhead dt app =
  let
    result =
      Playhead.step
        { playhead: app.playhead
        , dtSeconds: dt
        , loopOn: app.loopOn
        , loopStart: app.loopStart
        , loopEnd: app.loopEnd
        , lastBar: Int.floor app.playhead
        }
    moved = app { playhead = result.playhead }
  in
    case result.changedBar of
      Just bar -> Reducer.applyAutomation bar moved
      Nothing -> moved

songById :: SongId -> App -> Maybe Song
songById songId app =
  Array.find (_.id >>> (_ == songId)) app.songs

toolboxById :: ToolboxId -> App -> Maybe Toolbox
toolboxById toolboxId app =
  Array.find (_.id >>> (_ == toolboxId)) app.toolboxes

blockById :: BlockId -> App -> Maybe Block
blockById blockId app =
  currentToolbox app >>= \toolbox ->
    Array.find (_.id >>> (_ == blockId)) toolbox.blocks

currentToolbox :: App -> Maybe Toolbox
currentToolbox app =
  app.currentToolboxId >>= \toolboxId -> toolboxById toolboxId app

currentBlocks :: App -> Array Block
currentBlocks app =
  case currentToolbox app of
    Just toolbox -> toolbox.blocks
    Nothing -> []

currentTracks :: App -> Array Track
currentTracks app =
  case app.currentSongId >>= \songId -> songById songId app of
    Just song -> song.tracks
    Nothing -> []

cellIsLaunchable :: TrackId -> CellId -> App -> Boolean
cellIsLaunchable trackId cellId app =
  case app.currentSongId >>= \songId -> songById songId app of
    Just song ->
      case Array.find (_.id >>> (_ == trackId)) song.tracks of
        Just track ->
          case Array.find (_.id >>> (_ == cellId)) track.cells of
            Just cell -> (authoritativeValidation app.backendValidation cell.code).valid
            Nothing -> false
        Nothing -> false
    Nothing -> false

cellIsActive :: TrackId -> CellId -> App -> Boolean
cellIsActive trackId cellId app =
  case app.currentSongId >>= \songId -> songById songId app of
    Just song ->
      case Array.find (_.id >>> (_ == trackId)) song.tracks of
        Just track -> track.active == Just cellId
        Nothing -> false
    Nothing -> false

acceptsDrop :: DropTarget -> App -> Boolean
acceptsDrop target app =
  case app.drag of
    Just drag
      | drag.kind == "track" ->
          target.kind == "track" && drag.trackId /= target.trackId
      | drag.kind == "cell" ->
          target.kind == "cell" || target.kind == "cell-append"
    _ ->
      false

applyDrop :: DropTarget -> App -> App
applyDrop target app =
  if not (acceptsDrop target app) then
    app
  else
    case app.drag of
      Just drag
        | drag.kind == "track" && target.kind == "track" ->
            Reducer.moveTrack drag.trackId target.trackId app
        | drag.kind == "cell" ->
            case drag.cellId of
              Just cellId ->
                Reducer.moveCell drag.trackId cellId target.trackId target.cellId app
              Nothing ->
                app
      _ ->
        app

clearDrag :: App -> App
clearDrag app =
  app { drag = Nothing, over = Nothing }

showToast :: forall output m. MonadAff m => String -> H.HalogenM App Action () output m Unit
showToast message = do
  H.modify_ \app -> app { toast = Just message }
  H.subscribe' \subscriptionId -> Files.timeoutEmitter 2400 (ClearToast subscriptionId message)

handleSocketEvent :: forall output m. MonadAff m => Int -> H.SubscriptionId -> WebSocket.WebSocketEvent -> H.HalogenM App Action () output m Unit
handleSocketEvent generation subscriptionId event = do
  app <- H.get
  if generation == app.websocketGeneration then
    handleCurrentSocketEvent subscriptionId event
  else
    case event of
      WebSocket.WebSocketClosed ->
        H.unsubscribe subscriptionId
      _ ->
        pure unit

handleCurrentSocketEvent :: forall output m. MonadAff m => H.SubscriptionId -> WebSocket.WebSocketEvent -> H.HalogenM App Action () output m Unit
handleCurrentSocketEvent subscriptionId = case _ of
  WebSocket.WebSocketReady socket ->
    H.modify_ (Reducer.setWebSocket (Just socket))
  WebSocket.WebSocketOpened -> do
    H.modify_ (Reducer.setConnection Connected)
    app <- H.get
    traverse_ sendWhenConnected (commandsForSocketOpen app)
  WebSocket.WebSocketClosed -> do
    H.unsubscribe subscriptionId
    H.modify_ (Reducer.setWebSocket Nothing <<< Reducer.setConnection Disconnected)
  WebSocket.WebSocketErrored message -> do
    H.modify_ (Reducer.setConnection (ConnectionError message))
    showToast ("WebSocket: " <> message)
  WebSocket.WebSocketReceived event ->
    handleServerEvent event

handleServerEvent :: forall output m. MonadAff m => Protocol.ServerEvent -> H.HalogenM App Action () output m Unit
handleServerEvent = case _ of
  Protocol.TextValidated result ->
    H.modify_ (Reducer.recordBackendValidation (authoritativeFromServer result))
  Protocol.CommandFailed failure ->
    showToast ("Command failed: " <> failure.message)
  Protocol.StateSnapshot _ ->
    pure unit

authoritativeFromServer :: Protocol.ValidationResult -> { source :: String, valid :: Boolean, error :: Maybe String }
authoritativeFromServer = case _ of
  Protocol.ValidationSucceeded source ->
    { source, valid: true, error: Nothing }
  Protocol.ValidationFailed source message ->
    { source, valid: false, error: Just message }

sendWhenConnected :: forall output m. MonadAff m => Protocol.ClientCommand -> H.HalogenM App Action () output m Unit
sendWhenConnected command = do
  app <- H.get
  case app.websocket of
    Just socket | canUseBackend app.connection ->
      H.liftEffect (WebSocket.sendCommand socket command)
    _ ->
      pure unit

commandsForSocketOpen :: App -> Array Protocol.ClientCommand
commandsForSocketOpen app =
  [ Protocol.SetSession (sessionFromApp app) ]

sessionFromApp :: App -> Protocol.Session
sessionFromApp app =
  { sessionSlotCapacity: totalBars
  , sessionTracks:
      Array.mapWithIndex trackFromApp (currentTracks app)
  , sessionDefinitions: blockFromApp <$> currentBlocks app
  }

trackFromApp :: Int -> Track -> Protocol.Track
trackFromApp index track =
  { trackId: track.id
  , trackName: track.name
  , trackSlot: index + 1
  , trackTexts: textFromApp <$> track.cells
  , trackActiveText: track.active
  , trackSelectedText: track.selected
  }

textFromApp :: Cell -> Protocol.TrackText
textFromApp cell =
  { trackTextId: cell.id
  , trackTextSource: cell.code
  }

blockFromApp :: Block -> Protocol.Block
blockFromApp block =
  { blockId: block.id
  , blockName: block.name
  , blockCode: block.code
  , blockApplied: block.applied
  }

sendPlaybackTransitions :: forall output m. MonadAff m => App -> App -> H.HalogenM App Action () output m Unit
sendPlaybackTransitions before after =
  traverse_ sendWhenConnected
    (Reducer.playbackCommandsForActiveTransitions (currentTracks before) (currentTracks after))

sendDefinitionAndApply :: forall output m. MonadAff m => Block -> H.HalogenM App Action () output m Unit
sendDefinitionAndApply block = do
  sendWhenConnected (Protocol.SaveDefinition block.id block.name block.code)
  sendWhenConnected (Protocol.ApplyDefinition block.id)

applyDelete :: forall output m. MonadAff m => MouseEvent -> (App -> App) -> H.HalogenM App Action () output m Unit
applyDelete event reducer = do
  stopMouseEvent event
  before <- H.get
  let
    after = reducer before
  H.put after
  scheduleConfirmTimeout before after

scheduleConfirmTimeout :: forall output m. MonadAff m => App -> App -> H.HalogenM App Action () output m Unit
scheduleConfirmTimeout before after =
  case after.confirm of
    Just key
      | before.confirm /= after.confirm || before.confirmToken /= after.confirmToken ->
          H.subscribe' \subscriptionId ->
            Files.timeoutEmitter 2800 (ConfirmTimeout subscriptionId key after.confirmToken)
    _ ->
      pure unit

stopMouseEvent :: forall output m. MonadAff m => MouseEvent -> H.HalogenM App Action () output m Unit
stopMouseEvent event =
  H.liftEffect (Event.stopPropagation (MouseEvent.toEvent event))

fileName :: String -> String -> String
fileName name kind =
  name <> ".riptide-" <> kind <> ".json"
