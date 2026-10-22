module PipelineSpec where

-- The whole pipeline, starting from piq source files on disk:
--
--     .piq source --YOUR PARSER--> AST --provided compiler--> Python
--
-- These tests read files, so run them from the top folder of the repository.

import PiqEvaluation
import PiqParser
import Examples (compileSource, helloProgram, exampleProgram, specCandidate)
import TestUtilities
import Test.Hspec


spec :: Spec
spec = describe "Part 10: the whole pipeline" $ do

    describe "Step 10.1: reading programs from files" $ do
        it "programs/hello.piq" $
            parseProgramFile "programs/hello.piq" `shouldReturn` helloProgram
        it "programs/example.piq" $
            parseProgramFile "programs/example.piq" `shouldReturn` exampleProgram
        it "programs/spec_candidate.piq" $
            parseProgramFile "programs/spec_candidate.piq" `shouldReturn` specCandidate
        -- 6 flowers (a stem, 5 circles and a dot each), the ground, 3 sun rings
        it "programs/garden.piq compiles to a drawing that lowers the pen 46 times" $ do
            parsed <- parseProgramFile "programs/garden.piq"
            penDowns (compileProgram parsed) `shouldBe` 46
        it "programs/garden.piq ends at the sun's centre, (-120, 90)" $ do
            parsed <- parseProgramFile "programs/garden.piq"
            netDisplacement (compileProgram parsed) `shouldBeNear` (-120, 90)
        -- frame 2, two lenses of 41 lines, 4 tunnels of 10 squares, 40 beads
        it "programs/woven.piq compiles to a drawing that lowers the pen 164 times" $ do
            parsed <- parseProgramFile "programs/woven.piq"
            penDowns (compileProgram parsed) `shouldBe` 164
        it "programs/woven.piq ends exactly where it started" $ do
            parsed <- parseProgramFile "programs/woven.piq"
            netDisplacement (compileProgram parsed) `shouldBeNear` (0, 0)

    describe "Step 10.2: source code to Python" $ do
        it "line up 10" $
            compileSource "line up 10" `shouldBe` ["pen_down()", "move_rel(0.0, 10.0)", "pen_up()"]
        it "the shadowing example draws squares of 120 and then 10" $
            compileSource "define foo(x) { x = x + 100 square x } x = 10 foo(20) square x"
                `shouldBe` squareCode 120 ++ squareCode 10
        it "a syntax error stops the pipeline" $
            compileSource "square 10 move right" `shouldCrashWith` ""
        it "an undefined variable stops the pipeline" $
            compileSource "square 10 circle r" `shouldCrashWith` "undefined variable: r"
        it "a call with the wrong number of arguments stops the pipeline" $
            compileSource "define f(a) { dot } f(1, 2)" `shouldCrashWith` "procedure f expects 1 arguments, got 2"
