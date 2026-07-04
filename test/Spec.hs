module Main
    ( main
    ) where

import Riptide (banner)
import Riptide.EvalSpec qualified
import Riptide.SessionSpec qualified
import Riptide.StoreSpec qualified
import Test.Hspec (describe, hspec, it, shouldContain)

main :: IO ()
main = hspec $ do
    Riptide.EvalSpec.spec
    Riptide.SessionSpec.spec
    Riptide.StoreSpec.spec
    describe "Riptide.banner" $ do
        it "names the application" $
            banner `shouldContain` "riptide"
