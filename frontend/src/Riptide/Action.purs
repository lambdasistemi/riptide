module Riptide.Action
  ( ControlKey(..)
  ) where

import Prelude

data ControlKey
  = Vol
  | Flt
  | Dly

derive instance eqControlKey :: Eq ControlKey

instance showControlKey :: Show ControlKey where
  show Vol = "vol"
  show Flt = "flt"
  show Dly = "dly"
