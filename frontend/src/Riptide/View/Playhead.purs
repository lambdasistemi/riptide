module Riptide.View.Playhead
  ( StepInput
  , StepOutput
  , animationFrameEmitter
  , secondsPerBar
  , step
  ) where

import Prelude

import Data.Int as Int
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Halogen.Subscription as HS
import Riptide.Model (totalBars)

type StepInput =
  { playhead :: Number
  , dtSeconds :: Number
  , loopOn :: Boolean
  , loopStart :: Int
  , loopEnd :: Int
  , lastBar :: Int
  }

type StepOutput =
  { playhead :: Number
  , bar :: Int
  , changedBar :: Maybe Int
  }

secondsPerBar :: Number
secondsPerBar = 1.6

step :: StepInput -> StepOutput
step input =
  let
    lo = if input.loopOn then input.loopStart else 0
    hi = if input.loopOn then input.loopEnd else totalBars
    loN = Int.toNumber lo
    hiN = Int.toNumber hi
    span = max 1.0 (hiN - loN)
    dt = max 0.0 (min 0.25 input.dtSeconds)
    advanced = input.playhead + dt / secondsPerBar
    wrapped
      | advanced < loN = loN
      | advanced >= hiN = loN + wrapDistance span (advanced - loN)
      | otherwise = advanced
    bar = clampInt 0 (totalBars - 1) (Int.floor wrapped)
  in
    { playhead: wrapped
    , bar
    , changedBar: if bar == input.lastBar then Nothing else Just bar
    }

animationFrameEmitter :: forall action. (Number -> action) -> HS.Emitter action
animationFrameEmitter toAction =
  map toAction (HS.makeEmitter animationFrames)

wrapDistance :: Number -> Number -> Number
wrapDistance span value =
  value - span * Int.toNumber (Int.floor (value / span))

clampInt :: Int -> Int -> Int -> Int
clampInt lo hi value =
  max lo (min hi value)

foreign import animationFrames :: (Number -> Effect Unit) -> Effect (Effect Unit)
