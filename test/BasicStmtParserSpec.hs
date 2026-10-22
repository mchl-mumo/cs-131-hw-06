module BasicStmtParserSpec where

import PiqAST
import PiqParser
import TestUtilities
import Test.Hspec


statementIs :: String -> Stmt -> Spec
statementIs = parsesTo parseStmt

rejected :: String -> Spec
rejected = failsToParse parseStmt


spec :: Spec
spec = describe "Part 4: basic statements" $ do

    describe "Step 4.1: dot (provided)" $ do
        "dot"       `statementIs` Dot
        "  dot  "   `statementIs` Dot
        rejected "dot 5"
        rejected "dots"

    describe "Step 4.2: square, rectangle, circle" $ do
        "square 20"              `statementIs` Square (Num 20)
        "square x / 2"           `statementIs` Square (Div (Var "x") (Num 2))
        "square squareSize"      `statementIs` Square (Var "squareSize")
        "circle 10"              `statementIs` Circle (Num 10)
        "circle r * 2 + 1"       `statementIs` Circle (Add (Mul (Var "r") (Num 2)) (Num 1))
        "rectangle 30 10"        `statementIs` Rectangle (Num 30) (Num 10)
        "rectangle w h"          `statementIs` Rectangle (Var "w") (Var "h")
        "rectangle w + 1 h * 2"  `statementIs` Rectangle (Add (Var "w") (Num 1)) (Mul (Var "h") (Num 2))
        "rectangle 30 (-10)"     `statementIs` Rectangle (Num 30) (Num (-10))
        "rectangle\n30\n10"      `statementIs` Rectangle (Num 30) (Num 10)
        rejected "square"
        rejected "circle"
        rejected "rectangle 30"
        rejected "rectangle 30 -10"      -- reads as rectangle (30 - 10), then no height
        rejected "Square 10"             -- keywords are lowercase
        rejected "squarex"               -- one name, not "square x"
        rejected "circler"
        rejected "rectangle1 2"

    describe "Step 4.3: directions, move and line" $ do
        it "direction reads all four directions" $
            map (parse direction) ["left", "right", "up", "down"] `shouldBe` [Lt, Rt, Up, Dn]
        "move left 5"            `statementIs` Move Lt (Num 5)
        "move right 5"           `statementIs` Move Rt (Num 5)
        "move up 5"              `statementIs` Move Up (Num 5)
        "move down 5"            `statementIs` Move Dn (Num 5)
        "move right gap + 1"     `statementIs` Move Rt (Add (Var "gap") (Num 1))
        "move left (-45)"        `statementIs` Move Lt (Num (-45))
        "line up upper"          `statementIs` Line Up (Var "upper")
        "line down 2.5"          `statementIs` Line Dn (Num 2.5)
        "  move\n  left\n  5  "  `statementIs` Move Lt (Num 5)
        rejected "move right"            -- distances are always required
        rejected "line up"
        rejected "move 10"               -- missing direction
        rejected "move forward 10"
        rejected "movedown 5"            -- one name, not "move down 5"
        rejected "lineup 3"
        rejected "move downward 5"       -- "downward" is not the direction "down"

    describe "Step 4.4: assignment" $ do
        "x = 20"                 `statementIs` Assign "x" (Num 20)
        "x=20"                   `statementIs` Assign "x" (Num 20)
        "size = size * 2"        `statementIs` Assign "size" (Mul (Var "size") (Num 2))
        "dotty = 3"              `statementIs` Assign "dotty" (Num 3)
        "forward = 1"            `statementIs` Assign "forward" (Num 1)
        "Dot = 2"                `statementIs` Assign "Dot" (Num 2)
        rejected "x ="
        rejected "= 3"
        rejected "3 = x"
        rejected "x == 3"
        rejected "dot = 1"               -- reserved words cannot be assigned to
        rejected "left = 1"
        rejected "for = 1"
        rejected "circle = 1"
