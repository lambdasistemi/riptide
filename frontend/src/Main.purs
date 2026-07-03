module Main where

import Prelude

import Effect (Effect)
import Halogen as H
import Halogen.Aff as HA
import Halogen.HTML as HH
import Halogen.VDom.Driver (runUI)

main :: Effect Unit
main = HA.runHalogenAff do
  body <- HA.awaitBody
  runUI component unit body

component :: forall query input output m. H.Component query input output m
component =
  H.mkComponent
    { initialState: const unit
    , render
    , eval: H.mkEval H.defaultEval
    }

render :: forall action slots m. Unit -> H.ComponentHTML action slots m
render _ =
  HH.main_
    [ HH.h1_ [ HH.text "riptide" ]
    , HH.p_ [ HH.text "frontend scaffold placeholder" ]
    ]
