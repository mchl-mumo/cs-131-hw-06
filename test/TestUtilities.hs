module TestUtilities where

-- Helpers used by the tests. PROVIDED: you do not need to change this file.

import PiqAST
import Test.Hspec
import Control.Exception (evaluate, ErrorCall(..))
import Data.List (isInfixOf, stripPrefix)


-- | Combines a list of specs into one spec
combineSpecs :: [Spec] -> Spec
combineSpecs = foldl (>>) (return ())


-- | A test that parsing the input (with the given parsing function) gives the
--   expected result
parsesTo :: (Show a, Eq a) => (String -> a) -> String -> a -> Spec
parsesTo parseIt input expected =
    it (show input ++ " parses to " ++ show expected) $
        parseIt input `shouldBe` expected


-- | A test that the parsing function REJECTS the input. (While a parser is
--   still unfinished, these tests may pass simply because it rejects
--   everything. They matter once the parser accepts things.)
failsToParse :: Show a => (String -> a) -> String -> Spec
failsToParse parseIt input =
    it (show input ++ " is rejected") $
        evaluate (length (show (parseIt input))) `shouldThrow` (\(ErrorCall _) -> True)


-- | Expects evaluating the value to crash with an error message that
--   contains the given text
shouldCrashWith :: Show a => a -> String -> Expectation
shouldCrashWith value message =
    evaluate (length (show value)) `shouldThrow` (\(ErrorCall actual) -> message `isInfixOf` actual)


--------------------------------------------------------------------------------
-- Looking inside programs
--------------------------------------------------------------------------------

-- | Every statement in a program, including inside loop bodies and procedures
programStmts :: Program -> [Stmt]
programStmts (Program defs mainStmts) = concatMap allStmts (concatMap procBody defs ++ mainStmts)
    where procBody (ProcDef _ _ body) = body
          allStmts (For v e1 e2 body) = For v e1 e2 body : concatMap allStmts body
          allStmts other              = [other]


-- | Every expression that appears anywhere in a program
programExprs :: Program -> [Expr]
programExprs program = concatMap stmtExprs (programStmts program)
    where stmtExprs (Assign _ e)      = [e]
          stmtExprs (Square e)        = [e]
          stmtExprs (Rectangle e1 e2) = [e1, e2]
          stmtExprs (Circle e)        = [e]
          stmtExprs (Move _ e)        = [e]
          stmtExprs (Line _ e)        = [e]
          stmtExprs (For _ e1 e2 _)   = [e1, e2]
          stmtExprs (Call _ args)     = args
          stmtExprs Dot               = []


-- | Is this a statement that Part 4's parsers handle (no loops or calls)?
isBasicStmt :: Stmt -> Bool
isBasicStmt (For _ _ _ _) = False
isBasicStmt (Call _ _)    = False
isBasicStmt _             = True


--------------------------------------------------------------------------------
-- Looking at compiled code (for the pipeline tests)
--------------------------------------------------------------------------------

-- | How many times the code lowers the pen
penDowns :: [String] -> Int
penDowns code = length (filter (== "pen_down()") code)


-- | The (dx, dy) of a move_rel line, or (0, 0) for any other line
moveAmount :: String -> (Double, Double)
moveAmount line =
    case stripPrefix "move_rel(" line of
        Nothing   -> (0, 0)
        Just rest -> (read dxText, read dyText)
            where (dxText, afterDx) = break (== ',') rest
                  dyText            = takeWhile (/= ')') (drop 2 afterDx)


-- | How far the pen ends up from where it started
netDisplacement :: [String] -> (Double, Double)
netDisplacement code = (sum (map fst moves), sum (map snd moves))
    where moves = map moveAmount code


-- | Expects two (dx, dy) pairs to be equal, up to floating-point rounding
shouldBeNear :: (Double, Double) -> (Double, Double) -> Expectation
shouldBeNear actual expected = actual `shouldSatisfy` closeEnough
    where closeEnough (x, y) = abs (x - fst expected) < 1e-9
                            && abs (y - snd expected) < 1e-9
