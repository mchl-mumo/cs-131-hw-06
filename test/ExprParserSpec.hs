module ExprParserSpec where

import PiqAST
import PiqParser
import TestUtilities
import Test.Hspec


expressionIs :: String -> Expr -> Spec
expressionIs = parsesTo parseExpr

rejected :: String -> Spec
rejected = failsToParse parseExpr


spec :: Spec
spec = do
  describe "Part 2: atoms" $ do

    describe "Step 2.1: numbers (provided)" $ do
        "20"        `expressionIs` Num 20
        "2.5"       `expressionIs` Num 2.5
        "-3"        `expressionIs` Num (-3)
        "1.0e-2"    `expressionIs` Num 0.01
        "   7   "   `expressionIs` Num 7
        rejected ""
        rejected "3."

    describe "Step 2.2: variables" $ do
        "x"         `expressionIs` Var "x"
        "size"      `expressionIs` Var "size"
        "starGap"   `expressionIs` Var "starGap"
        -- names that merely START with a reserved word are fine
        "dotty"     `expressionIs` Var "dotty"
        "upper"     `expressionIs` Var "upper"
        "tofu"      `expressionIs` Var "tofu"
        -- reserved words are not variables
        rejected "dot"
        rejected "left"
        rejected "from"
        rejected "define"

    describe "Step 2.3: parentheses" $ do
        "(x)"       `expressionIs` Var "x"
        "((7))"     `expressionIs` Num 7
        "(-10)"     `expressionIs` Num (-10)
        "( size )"  `expressionIs` Var "size"
        rejected "()"
        rejected "(up)"
        rejected "(1"

  describe "Part 3: precedence and associativity" $ do

    describe "Step 3.1: combineLeft" $ do
        it "no pairs: just the first operand" $
            combineLeft (Num 1) [] `shouldBe` Num 1
        it "one pair" $
            combineLeft (Num 1) [(Add, Num 2)] `shouldBe` Add (Num 1) (Num 2)
        it "10 - 3 - 2 combines from the left: (10 - 3) - 2" $
            combineLeft (Num 10) [(Sub, Num 3), (Sub, Num 2)]
                `shouldBe` Sub (Sub (Num 10) (Num 3)) (Num 2)
        it "different operators, still from the left" $
            combineLeft (Var "a") [(Mul, Var "b"), (Div, Var "c"), (Mul, Var "d")]
                `shouldBe` Mul (Div (Mul (Var "a") (Var "b")) (Var "c")) (Var "d")

    describe "Step 3.2: terms (* and /)" $ do
        "2 * 3"         `expressionIs` Mul (Num 2) (Num 3)
        "x / 2"         `expressionIs` Div (Var "x") (Num 2)
        "8 / 4 / 2"     `expressionIs` Div (Div (Num 8) (Num 4)) (Num 2)
        "2 * 3 / 4 * 5" `expressionIs` Mul (Div (Mul (Num 2) (Num 3)) (Num 4)) (Num 5)
        "2*x"           `expressionIs` Mul (Num 2) (Var "x")

    describe "Step 3.3: expressions (+ and -, and precedence)" $ do
        "1 + 2"                 `expressionIs` Add (Num 1) (Num 2)
        "10 - 3 - 2"            `expressionIs` Sub (Sub (Num 10) (Num 3)) (Num 2)
        "1 + 2 - 3 + 4"         `expressionIs` Add (Sub (Add (Num 1) (Num 2)) (Num 3)) (Num 4)
        -- * and / bind tighter than + and -
        "x + 5 * 2"             `expressionIs` Add (Var "x") (Mul (Num 5) (Num 2))
        "1 * 2 + 3"             `expressionIs` Add (Mul (Num 1) (Num 2)) (Num 3)
        "10 - 6 / 2"            `expressionIs` Sub (Num 10) (Div (Num 6) (Num 2))
        "a * b + c * d"         `expressionIs` Add (Mul (Var "a") (Var "b")) (Mul (Var "c") (Var "d"))
        -- parentheses override precedence
        "(1 + 2) * 3"           `expressionIs` Mul (Add (Num 1) (Num 2)) (Num 3)
        "10 - (3 - 2)"          `expressionIs` Sub (Num 10) (Sub (Num 3) (Num 2))
        -- whitespace, including newlines, does not matter
        "1+2*3"                 `expressionIs` Add (Num 1) (Mul (Num 2) (Num 3))
        "  1 +\n  2\n * 3 "     `expressionIs` Add (Num 1) (Mul (Num 2) (Num 3))
        -- minus signs: a leading - belongs to a number
        "x-3"                   `expressionIs` Sub (Var "x") (Num 3)
        "x - -3"                `expressionIs` Sub (Var "x") (Num (-3))
        "0 - x"                 `expressionIs` Sub (Num 0) (Var "x")
        -- the way the pretty-printer writes things
        "((cols * step) + gap)" `expressionIs` Add (Mul (Var "cols") (Var "step")) (Var "gap")
        rejected "1 +"
        rejected "* 2"
        rejected "1 + 2)"
        rejected "x y"
        rejected "-x"
        rejected "1 ++ 2"
        rejected "x + left"
