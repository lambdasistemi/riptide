module Main
    ( main
    ) where

import Riptide (banner)
import Test.Hspec (describe, hspec, it, shouldContain)

main :: IO ()
main = hspec $ do
    describe "Riptide.banner" $ do
        it "names the application" $
            banner `shouldContain` "riptide"
