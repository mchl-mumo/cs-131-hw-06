{-|
Module       : PiqPretty
Description  : Turns piq abstract syntax back into piq concrete syntax.

The pretty-printer settles what piq source code looks like, and its output
is exactly what the parser (Week 2) must be able to read back. It keeps
things simple rather than minimal: every arithmetic operation gets its own
parentheses, so the printer never has to think about precedence.
-}

module PiqPretty where

import PiqAST

import Data.List (intercalate)


--------------------------------------------------------------------------------
-- Expressions
--------------------------------------------------------------------------------

-- | Prints a number, leaving off ".0" for whole numbers:
--   20.0 prints as "20", but 2.5 prints as "2.5".
prettyNumber :: Double -> String
prettyNumber n
    | isWhole   = show (round n :: Integer)
    | otherwise = show n
    -- Very large numbers keep Haskell's own format (such as 1.0e20) rather
    -- than being written out with twenty digits.
    where isWhole = n == fromIntegral (round n :: Integer) && abs n < 1e15


-- | Prints an expression, with parentheses around every operation.
--   For example, Add (Var "x") (Mul (Num 5) (Num 2)) prints as (x + (5 * 2)).
prettyExpr :: Expr -> String
prettyExpr (Num n)
    -- A negative number gets parentheses too. Otherwise "rectangle 30 -10"
    -- would read as "rectangle (30 - 10)" followed by a missing height.
    | n < 0     = "(" ++ prettyNumber n ++ ")"
    | otherwise = prettyNumber n
prettyExpr (Var name)  = name
prettyExpr (Add e1 e2) = prettyOperation e1 "+" e2
prettyExpr (Sub e1 e2) = prettyOperation e1 "-" e2
prettyExpr (Mul e1 e2) = prettyOperation e1 "*" e2
prettyExpr (Div e1 e2) = prettyOperation e1 "/" e2


-- | Prints "(e1 op e2)"
prettyOperation :: Expr -> String -> Expr -> String
prettyOperation e1 op e2 = "(" ++ prettyExpr e1 ++ " " ++ op ++ " " ++ prettyExpr e2 ++ ")"


--------------------------------------------------------------------------------
-- Statements
--------------------------------------------------------------------------------

-- | Prints a direction as the word used in piq source code
prettyDirection :: Direction -> String
prettyDirection Lt = "left"
prettyDirection Rt = "right"
prettyDirection Up = "up"
prettyDirection Dn = "down"


-- | Prints one statement
prettyStmt :: Stmt -> String
prettyStmt (Assign name expr)  = name ++ " = " ++ prettyExpr expr
prettyStmt Dot                 = "dot"
prettyStmt (Square side)       = "square " ++ prettyExpr side
prettyStmt (Rectangle wid ht)  = "rectangle " ++ prettyExpr wid ++ " " ++ prettyExpr ht
prettyStmt (Circle radius)     = "circle " ++ prettyExpr radius
prettyStmt (Move dir distance) = "move " ++ prettyDirection dir ++ " " ++ prettyExpr distance
prettyStmt (Line dir distance) = "line " ++ prettyDirection dir ++ " " ++ prettyExpr distance
prettyStmt (Call name args)    = name ++ "(" ++ commaSeparated (map prettyExpr args) ++ ")"
prettyStmt (For var from to body) =
    "for " ++ var ++ " from " ++ prettyExpr from ++ " to " ++ prettyExpr to ++ " {\n"
    ++ indent (prettyStmts body)
    ++ "}"


-- | Indents every line of some text by four spaces. The body of a loop is
--   printed this way; a loop inside a loop gets indented twice.
indent :: String -> String
indent text = unlines (map ("    " ++) (lines text))


-- | Prints a sequence of statements, one per line
prettyStmts :: [Stmt] -> String
prettyStmts stmts = unlines (map prettyStmt stmts)


-- | Joins items with commas: ["a", "b", "c"] becomes "a, b, c"
commaSeparated :: [String] -> String
commaSeparated items = intercalate ", " items


--------------------------------------------------------------------------------
-- Procedures and programs
--------------------------------------------------------------------------------

-- | Prints a procedure definition, with its body indented
prettyProcDef :: ProcDef -> String
prettyProcDef (ProcDef name params body) =
    "define " ++ name ++ "(" ++ commaSeparated params ++ ") {\n"
    ++ indent (prettyStmts body)
    ++ "}"


-- | Prints a whole program: each procedure definition followed by a blank
--   line, then the program's statements.
prettyProgram :: Program -> String
prettyProgram (Program defs stmts) =
    concatMap (\def -> prettyProcDef def ++ "\n\n") defs ++ prettyStmts stmts

