module RoundTripSpec where

-- Round trips: pretty-print an AST into source code, parse it back, and check
-- that the very same AST comes out. If parsing really recovers the structure
-- of the source, this holds for every valid AST.

import PiqAST
import PiqParser
import PiqPretty
import PiqEvaluation (compileProgram)
import Examples (lastWeeksExamples, part6Boxes, part7Tiles)
import TestUtilities
import Test.Hspec


-- | Hand-picked expressions for round trips
someExprs :: [Expr]
someExprs =
    [ Num 20, Num 2.5, Num (-10), Num 0.01, Num (1 / 3)
    , Var "size"
    , Add (Var "x") (Mul (Num 5) (Num 2))
    , Mul (Add (Var "x") (Num 5)) (Num 2)
    , Sub (Sub (Num 10) (Num 3)) (Num 2)
    , Sub (Num 10) (Sub (Num 3) (Num 2))
    , Div (Num 8) (Div (Num 4) (Num 2))
    , Sub (Var "x") (Num (-3))
    , Add (Mul (Var "a") (Var "b")) (Div (Var "c") (Sub (Var "d") (Num 1.5)))
    ]

-- | box, from last week's examples, as a person would type it (fewer
--   parentheses, different layout)
handWrittenBoxes :: String
handWrittenBoxes = unlines
    [ "define box(size, gap) {"
    , "    move right size / 2"
    , "    square size"
    , "    move right size / 2 + gap"
    , "}"
    , "move left 80"
    , "for i from 1 to 5 { box(i * 8, 10) }"
    ]

-- | tiles, from last week's examples, as a person would type it
handWrittenTiles :: String
handWrittenTiles = unlines
    [ "define tile(s) {"
    , "  square s   circle s / 2   dot"
    , "}"
    , "spacing = 40"
    , "move left 2.5 * spacing"
    , "move up 1.5 * spacing"
    , "for row from 1 to 4 {"
    , "  for col from 1 to 6 {"
    , "    tile(10 + 2 * (row + col))"
    , "    move right spacing"
    , "  }"
    , "  move left 6 * spacing"
    , "  move down spacing"
    , "}"
    ]


spec :: Spec
spec = do
  describe "Part 3: precedence and associativity" $
    describe "Step 3.4: expression round trips" $ do
        combineSpecs [ it ("parseExpr (prettyExpr e) == e  for  " ++ prettyExpr e) $
                           parseExpr (prettyExpr e) `shouldBe` e
                     | e <- someExprs ]
        it "every expression in last week's examples survives printing and parsing" $
            concatMap (\(_, p) -> map (parseExpr . prettyExpr) (programExprs p)) lastWeeksExamples
                `shouldBe` concatMap (\(_, p) -> programExprs p) lastWeeksExamples

  describe "Part 4: basic statements" $
    describe "Step 4.5: statement round trips" $
        it "every basic statement in last week's examples survives printing and parsing" $
            let basics = concatMap (\(_, p) -> filter isBasicStmt (programStmts p)) lastWeeksExamples
            in  map (parseStmt . prettyStmt) basics `shouldBe` basics

  describe "Part 9: whole programs" $
    describe "Step 9.2: program round trips" $ do
        combineSpecs [ it ("parseProgram (prettyProgram p) == p  for  " ++ label) $
                           parseProgram (prettyProgram p) `shouldBe` p
                     | (label, p) <- lastWeeksExamples ]
        -- lists the examples whose Python differs (comparing all of the Python
        -- directly would make a failure message far too long to read)
        it "the parsed programs compile to exactly the same Python" $
            [ label | (label, p) <- lastWeeksExamples
                    , compileProgram (parseProgram (prettyProgram p)) /= compileProgram p ]
                `shouldBe` []
        it "hand-written source for part6Boxes gives exactly its AST" $
            parseProgram handWrittenBoxes `shouldBe` part6Boxes
        it "hand-written source for part7Tiles gives exactly its AST" $
            parseProgram handWrittenTiles `shouldBe` part7Tiles
