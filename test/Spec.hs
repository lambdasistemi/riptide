module Main
    ( main
    ) where

import Riptide (banner)
import Riptide.SessionSpec qualified
import Test.Hspec (describe, hspec, it, shouldContain)

main :: IO ()
main = hspec $ do
    Riptide.SessionSpec.spec
    describe "Riptide.banner" $ do
        it "names the application" $
            banner `shouldContain` "riptide"
