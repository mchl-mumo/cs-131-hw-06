module ProcParserSpec where

import PiqAST
import PiqParser
import Examples (part6Shadowing)
import TestUtilities
import Test.Hspec


spec :: Spec
spec = do
  describe "Part 7: procedure calls" $
    describe "Step 7.1: calls" $ do
        let statementIs = parsesTo parseStmt
            rejected    = failsToParse parseStmt
        "star()"                      `statementIs` Call "star" []
        "star ( )"                    `statementIs` Call "star" []
        "ring(5)"                     `statementIs` Call "ring" [Num 5]
        "box(20, 5)"                  `statementIs` Call "box" [Num 20, Num 5]
        "box( 20 ,5 )"                `statementIs` Call "box" [Num 20, Num 5]
        "box(i * 8, 10)"              `statementIs` Call "box" [Mul (Var "i") (Num 8), Num 10]
        "f(x + 1, (y), -3)"           `statementIs` Call "f" [Add (Var "x") (Num 1), Var "y", Num (-3)]
        "dotty(3)"                    `statementIs` Call "dotty" [Num 3]
        "for i from 1 to 2 { ring(i) }" `statementIs` For "i" (Num 1) (Num 2) [Call "ring" [Var "i"]]
        rejected "box("
        rejected "box(1,)"
        rejected "box(,)"
        rejected "box(1 2)"
        rejected "box 1"
        rejected "dot(3)"                   -- dot is a keyword, not a procedure name
        rejected "left(3)"

  describe "Part 8: procedure definitions" $
    describe "Step 8.1: define" $ do
        let definitionIs = parsesTo (parse procDef)
            rejected     = failsToParse (parse procDef)
        "define star() { dot }"       `definitionIs` ProcDef "star" [] [Dot]
        "define empty() { }"          `definitionIs` ProcDef "empty" [] []
        "define ring(r) { circle r }" `definitionIs` ProcDef "ring" ["r"] [Circle (Var "r")]
        "define box(size, gap) { square size move right size + gap }"
            `definitionIs` ProcDef "box" ["size", "gap"] [Square (Var "size"), Move Rt (Add (Var "size") (Var "gap"))]
        "define row(n) {\n  for i from 1 to n {\n    ring(i * 2)\n  }\n}"
            `definitionIs` ProcDef "row" ["n"] [For "i" (Num 1) (Var "n") [Call "ring" [Mul (Var "i") (Num 2)]]]
        "define dotty(forward, upper) { }" `definitionIs` ProcDef "dotty" ["forward", "upper"] []
        rejected "define dot() { }"             -- reserved word as the procedure name
        rejected "define f(dot) { }"            -- reserved word as a parameter
        rejected "define f(1) { }"
        rejected "define f(a b) { }"
        rejected "define f { }"                 -- the parentheses are required
        rejected "define f() dot"               -- the body needs braces
        rejected "define f() { define g() { } }" -- no nested definitions
        rejected "def f() { }"

  describe "Part 9: whole programs" $
    describe "Step 9.1: programs" $ do
        let programIs = parsesTo parseProgram
            rejected  = failsToParse parseProgram
        ""                                        `programIs` Program [] []
        "dot"                                     `programIs` Program [] [Dot]
        "define star() { dot }"                   `programIs` Program [ProcDef "star" [] [Dot]] []
        "define star() { dot } star() star()"     `programIs` Program [ProcDef "star" [] [Dot]] [Call "star" [], Call "star" []]
        "define a() { b() } define b() { dot } a()"
            `programIs` Program [ProcDef "a" [] [Call "b" []], ProcDef "b" [] [Dot]] [Call "a" []]
        unlines [ "define foo(x) {"
                , "    x = x + 100"
                , "    square x"
                , "}"
                , ""
                , "x = 10"
                , "foo(20)"
                , "square x" ] `programIs` part6Shadowing
        rejected "dot define f() { }"           -- definitions must come before statements
        rejected "define f() { } dot define g() { }"
        rejected "}"
        rejected "{ dot }"                      -- a block is not a statement by itself
        rejected "move right"
