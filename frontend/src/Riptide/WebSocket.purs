module Riptide.WebSocket
  ( WebSocketClient
  , WebSocketHandlers
  , close
  , connect
  , sendCommand
  ) where

import Prelude

import Data.Either (Either(..))
import Effect (Effect)
import Riptide.Protocol.Client (ClientCommand, ServerEvent, decodeServerEvent, encodeClientCommand)

foreign import data WebSocketClient :: Type

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

foreign import connectImpl ::
  { onOpen :: Effect Unit
  , onClose :: Effect Unit
  , onError :: String -> Effect Unit
  , onMessage :: String -> Effect Unit
  } ->
  Effect WebSocketClient

foreign import sendImpl :: WebSocketClient -> String -> Effect Unit

foreign import close :: WebSocketClient -> Effect Unit
