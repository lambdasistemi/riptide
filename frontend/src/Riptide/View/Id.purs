module Riptide.View.Id
  ( mintId
  ) where

import Effect (Effect)

foreign import mintId :: String -> Effect String
