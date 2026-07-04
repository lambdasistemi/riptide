module Riptide.EvalSpec
    ( spec
    ) where

import Riptide.Eval
    ( validateControlPattern
    , validateControlPatternWithDefinitions
    )
import Test.Hspec
    ( Spec
    , describe
    , expectationFailure
    , it
    , shouldBe
    )

spec :: Spec
spec =
    describe "Riptide.Eval" $ do
        it "validates a track referencing a scoped definition" $ do
            result <-
                validateControlPatternWithDefinitions
                    ["let arpy = sound \"bd\""]
                    "arpy"

            shouldValidate result

        it "validates a track referencing two scoped definitions" $ do
            result <-
                validateControlPatternWithDefinitions
                    ["let a = sound \"bd\"", "let b = sound \"sn\""]
                    "stack [a, b]"

            shouldValidate result

        it "fails when a track references an undefined name" $ do
            result <-
                validateControlPatternWithDefinitions
                    []
                    "missingDefinition $ sound \"bd\""

            case result of
                Left _ -> pure ()
                Right value ->
                    expectationFailure $
                        "expected undefined name to fail, got " <> show value

        it "fails when a scoped definition is syntactically broken" $ do
            result <-
                validateControlPatternWithDefinitions
                    ["let feel ="]
                    "feel $ sound \"bd\""

            case result of
                Left _ -> pure ()
                Right value ->
                    expectationFailure $
                        "expected broken definition to fail, got " <> show value

        it "matches the old empty-scope validation path" $ do
            scoped <- validateControlPatternWithDefinitions [] "sound \"bd\""
            old <- validateControlPattern "sound \"bd\""

            shouldValidate scoped
            shouldValidate old

shouldValidate :: Either error Bool -> IO ()
shouldValidate result =
    case result of
        Right value -> value `shouldBe` True
        Left _ -> expectationFailure "expected validation to succeed"
