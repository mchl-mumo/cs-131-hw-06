module BlockParserSpec where

import PiqAST
import PiqParser
import ParserCombinators (text, many, (<|>), (>>:))
import TestUtilities
import Test.Hspec


spec :: Spec
spec = do
  describe "Part 5: statement sequences and blocks" $ do

    describe "Step 5.1: sequences" $ do
        let sequenceIs = parsesTo parseStmts
            rejected   = failsToParse parseStmts
            fourStmts  = [ Assign "x" (Num 10), Square (Var "x")
                         , Assign "x" (Mul (Var "x") (Num 2)), Square (Var "x") ]
        ""                                        `sequenceIs` []
        "dot dot"                                 `sequenceIs` [Dot, Dot]
        -- the same program on separate lines and all on one line
        "x = 10\nsquare x\nx = x * 2\nsquare x"   `sequenceIs` fourStmts
        "x = 10 square x x = x * 2 square x"      `sequenceIs` fourStmts
        -- a statement ends where its last expression ends
        "square x y = 3"                          `sequenceIs` [Square (Var "x"), Assign "y" (Num 3)]
        "move right step line up 5"               `sequenceIs` [Move Rt (Var "step"), Line Up (Num 5)]
        "rectangle w h dot"                       `sequenceIs` [Rectangle (Var "w") (Var "h"), Dot]
        -- a name that starts with a keyword is NOT split into the keyword and the rest
        "dot dotty = 3 dot"                       `sequenceIs` [Dot, Assign "dotty" (Num 3), Dot]
        rejected "dot 5 dot"
        rejected "square 10 move right"
        rejected "x = 3 y"
        rejected "dotdot"
        -- why `keyword` exists: with `text "dot"`, "dotty = 3" would read as
        -- a dot followed by the assignment "ty = 3"
        it "(for comparison) matching the keyword with text would split dotty into dot and ty" $
            parse (many ((text "dot" >>: Dot) <|> assignment)) "dotty = 3"
                `shouldBe` [Dot, Assign "ty" (Num 3)]

    describe "Step 5.2: blocks" $ do
        let blockIs  = parsesTo (parse block)
            rejected = failsToParse (parse block)
        "{}"                          `blockIs` []
        "{ }"                         `blockIs` []
        "{ dot }"                     `blockIs` [Dot]
        "{ dot square 3 }"            `blockIs` [Dot, Square (Num 3)]
        "{\n    dot\n    line up 5\n}" `blockIs` [Dot, Line Up (Num 5)]
        rejected "{ dot"
        rejected "dot }"
        rejected "dot"

  describe "Part 6: loops" $ do

    describe "Step 6.1: for loops" $ do
        let statementIs = parsesTo parseStmt
            rejected    = failsToParse parseStmt
        "for i from 1 to 5 { dot }"              `statementIs` For "i" (Num 1) (Num 5) [Dot]
        "for i from 1 to 5 {}"                   `statementIs` For "i" (Num 1) (Num 5) []
        "for i from 1 to 3 { dot move right 5 }" `statementIs` For "i" (Num 1) (Num 3) [Dot, Move Rt (Num 5)]
        "for i from 1 to 3 {\n    dot\n}"        `statementIs` For "i" (Num 1) (Num 3) [Dot]
        "for k from (-2) to n - 1 { square k }"  `statementIs` For "k" (Num (-2)) (Sub (Var "n") (Num 1)) [Square (Var "k")]
        "for form from 1 to 2 { }"               `statementIs` For "form" (Num 1) (Num 2) []
        rejected "for i from 1 to 5 dot"         -- the body needs braces
        rejected "for i from 1 to 5 { dot"
        rejected "for i from 1 { dot }"          -- missing "to"
        rejected "for i to 5 { dot }"            -- missing "from"
        rejected "for i = 1 to 3 { dot }"
        rejected "for 1 from 1 to 2 { }"         -- the loop variable must be a name
        rejected "for dot from 1 to 2 { }"       -- ... and not a reserved word

    describe "Step 6.2: nested loops" $ do
        let statementIs = parsesTo parseStmt
        "for i from 1 to 2 { for j from 1 to 3 { dot } move down 10 }"
            `statementIs` For "i" (Num 1) (Num 2) [ For "j" (Num 1) (Num 3) [Dot], Move Dn (Num 10) ]
        "for i from 1 to 2 { for j from 1 to i { for k from j to 3 { square i * j * k } } }"
            `statementIs` For "i" (Num 1) (Num 2)
                            [ For "j" (Num 1) (Var "i")
                                [ For "k" (Var "j") (Num 3)
                                    [ Square (Mul (Mul (Var "i") (Var "j")) (Var "k")) ] ] ]
