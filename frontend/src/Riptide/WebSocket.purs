module Riptide.WebSocket
  ( WebSocketClient
  , WebSocketEvent(..)
  , WebSocketHandlers
  , close
  , connect
  , connectEmitter
  , sendCommand
  ) where

import Prelude

import Data.Either (Either(..))
import Effect (Effect)
import Halogen.Subscription as HS
import Riptide.Protocol.Client (ClientCommand, ServerEvent, decodeServerEvent, encodeClientCommand)

foreign import data WebSocketClient :: Type

data WebSocketEvent
  = WebSocketReady WebSocketClient
  | WebSocketOpened
  | WebSocketClosed
  | WebSocketErrored String
  | WebSocketReceived ServerEvent

type WebSocketHandlers =
  { onOpen :: Effect Unit
  , onClose :: Effect Unit
  , onError :: String -> Effect Unit
  , onMessage :: ServerEvent -> Effect Unit
  }

connect :: WebSocketHandlers -> Effect WebSocketClient
connect handlers =
  connectImpl
    { onOpen: handlers.onOpen
    , onClose: handlers.onClose
    , onError: handlers.onError
    , onMessage:
        \message ->
          case decodeServerEvent message of
            Left err -> handlers.onError err
            Right event -> handlers.onMessage event
    }

sendCommand :: WebSocketClient -> ClientCommand -> Effect Unit
sendCommand socket =
  sendImpl socket <<< encodeClientCommand

connectEmitter :: forall action. (WebSocketEvent -> action) -> HS.Emitter action
connectEmitter toAction =
  map toAction $ HS.makeEmitter \emit -> do
    socket <-
      connect
        { onOpen: emit WebSocketOpened
        , onClose: emit WebSocketClosed
        , onError: emit <<< WebSocketErrored
        , onMessage: emit <<< WebSocketReceived
        }
    emit (WebSocketReady socket)
    pure (close socket)

foreign import connectImpl ::
  { onOpen :: Effect Unit
  , onClose :: Effect Unit
  , onError :: String -> Effect Unit
  , onMessage :: String -> Effect Unit
  } ->
  Effect WebSocketClient

foreign import sendImpl :: WebSocketClient -> String -> Effect Unit

foreign import close :: WebSocketClient -> Effect Unit
