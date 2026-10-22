{-|
Module       : PiqParser
Description  : A parser for piq programs, built with the course's parser
               combinators. It turns piq source code into the abstract
               syntax from PiqAST.

**YOU WILL EDIT THIS FILE.**

Every place you need to fill in is marked

    -- TODO (Part N): ...

Work through the parts in the order given in ASSIGNMENT.md. Most unfinished
parsers start out as `pfail`, a parser that always fails. That way the parsers
that combine them (like `stmt`) keep working while you fill in the pieces one
at a time. Functions that are not parsers start out as an `error` saying which
TODO they are.

SYNTAX.md describes exactly what this parser must accept.
-}

module PiqParser (module PiqParser, parse, parseFile) where

import ParserCombinators
import PiqAST


--------------------------------------------------------------------------------
-- Part 1: reserved words and names
--------------------------------------------------------------------------------

-- | Words that have a special meaning in piq, so they cannot be used as the
--   name of a variable, parameter, or procedure.  (PROVIDED)
reservedWords :: [String]
reservedWords =
    [ "dot", "square", "rectangle", "circle", "move", "line"
    , "left", "right", "up", "down"
    , "for", "from", "to", "define"
    ]


-- | Is this word reserved?
isReserved :: String -> Bool
isReserved word =
    -- TODO (Part 1): one line; `elem` checks whether a list contains a value.
    error "TODO (Part 1): isReserved"


-- | A name (of a variable, parameter or procedure): an identifier that is not
--   a reserved word.
name :: Parser Name
name =
    -- TODO (Part 1): start from the library's `identifier`, and keep its
    --   result only if it is not reserved (the library's <=> filter).
    pfail


-- | Exactly the given reserved word, as a whole word: `keyword "dot"` accepts
--   "dot" but not the start of "dotty". (ASSIGNMENT.md, Part 1, explains why
--   `text "dot"` is not good enough.)
keyword :: String -> Parser String
keyword word =
    -- TODO (Part 1): read a whole identifier, then keep it only if it is
    --   exactly `word`.
    pfail


--------------------------------------------------------------------------------
-- Parts 2 and 3: expressions
--
--     expr   ::= term   (("+" | "-") term)*
--     term   ::= factor (("*" | "/") factor)*
--     factor ::= number | name | "(" expr ")"
--
-- All four operators are left associative: 10 - 3 - 2 means (10 - 3) - 2.
--------------------------------------------------------------------------------

-- | An expression: terms separated by + or -
expr :: Parser Expr
expr =
    -- TODO (Part 3): replace this placeholder. For now an expression is just
    --   a term, so that numbers can be parsed from the very start.
    term


-- | A term: factors separated by * or /
term :: Parser Expr
term =
    -- TODO (Part 3): replace this placeholder. For now a term is just a factor.
    factor


-- | A factor: a number, a variable, or an expression in parentheses
factor :: Parser Expr
factor =     (double >>=: Num)        -- PROVIDED: a number becomes a Num
             -- TODO (Part 2): add alternatives for a variable (a name) and
             --   for an expression in parentheses.
         <???> "a number, a name, or ( expected"


-- | + or -, returning the AST constructor for that operation
addOp :: Parser (Expr -> Expr -> Expr)
addOp =
    -- TODO (Part 3)
    pfail


-- | * or /, returning the AST constructor for that operation
mulOp :: Parser (Expr -> Expr -> Expr)
mulOp =
    -- TODO (Part 3)
    pfail


-- | Combines a first operand with a list of (operator, operand) pairs, FROM
--   THE LEFT. For example, 10 - 3 - 2 is read as the first operand 10 and the
--   pairs [(Sub, 3), (Sub, 2)], which combine to Sub (Sub 10 3) 2.
combineLeft :: Expr -> [(Expr -> Expr -> Expr, Expr)] -> Expr
combineLeft left pairs =
    -- TODO (Part 3): recursion on the list of pairs, carrying the combined
    --   expression so far.
    error "TODO (Part 3): combineLeft"


--------------------------------------------------------------------------------
-- Parts 4-7: statements
--
-- Every statement except assignment and call starts with its own reserved
-- word. Assignments and calls start with a name, which can never be a reserved
-- word; after the name, "=" means assignment and "(" means call.
--------------------------------------------------------------------------------

-- | A single statement: tries each kind of statement in turn.  (PROVIDED)
stmt :: Parser Stmt
stmt =     assignment
       <|> call
       <|> forLoop
       <|> dotStmt
       <|> squareStmt
       <|> rectangleStmt
       <|> circleStmt
       <|> moveStmt
       <|> lineStmt


-- | dot  (PROVIDED: an example of a statement parser)
dotStmt :: Parser Stmt
dotStmt = keyword "dot" >>: Dot


-- | square EXPR
squareStmt :: Parser Stmt
squareStmt =
    -- TODO (Part 4)
    pfail


-- | rectangle EXPR EXPR   (width, then height)
rectangleStmt :: Parser Stmt
rectangleStmt =
    -- TODO (Part 4)
    pfail


-- | circle EXPR   (the radius)
circleStmt :: Parser Stmt
circleStmt =
    -- TODO (Part 4)
    pfail


-- | One of the four directions: left, right, up, down
direction :: Parser Direction
direction =     (keyword "left" >>: Lt)       -- PROVIDED: one direction
                -- TODO (Part 4): add alternatives for right, up and down


-- | move DIRECTION EXPR
moveStmt :: Parser Stmt
moveStmt =
    -- TODO (Part 4)
    pfail


-- | line DIRECTION EXPR
lineStmt :: Parser Stmt
lineStmt =
    -- TODO (Part 4)
    pfail


-- | NAME = EXPR
assignment :: Parser Stmt
assignment =
    -- TODO (Part 4)
    pfail


-- | Any number of statements, one after another. Nothing separates them.
stmts :: Parser [Stmt]
stmts =
    -- TODO (Part 5)
    pfail


-- | A block: statements between braces
block :: Parser [Stmt]
block =
    -- TODO (Part 5)
    pfail


-- | for NAME from EXPR to EXPR BLOCK
forLoop :: Parser Stmt
forLoop =
    -- TODO (Part 6)
    pfail


-- | NAME(EXPR, EXPR, ...)   -- a procedure call; there may be no arguments
call :: Parser Stmt
call =
    -- TODO (Part 7)
    pfail


--------------------------------------------------------------------------------
-- Parts 8 and 9: procedure definitions and whole programs
--
--     program ::= procDef* stmt*
--     procDef ::= "define" name "(" names? ")" block
--
-- All procedure definitions come first, then the statements to run.
--------------------------------------------------------------------------------

-- | define NAME(NAME, NAME, ...) BLOCK
procDef :: Parser ProcDef
procDef =
    -- TODO (Part 8)
    pfail


-- | A whole program: procedure definitions, then statements
program :: Parser Program
program =
    -- TODO (Part 9)
    pfail


--------------------------------------------------------------------------------
-- Parsing whole strings and files  (PROVIDED)
--
-- Each of these parses the ENTIRE input (allowing whitespace at the end), and
-- stops with an error message if the input is not exactly one expression /
-- statement / ... . Use them in GHCI to try out your parsers.
--------------------------------------------------------------------------------

-- | Parses a string that contains exactly one expression.
parseExpr :: String -> Expr
parseExpr input = parse (expr <+-> whitespace) input


-- | Parses a string that contains exactly one statement.
parseStmt :: String -> Stmt
parseStmt input = parse (stmt <+-> whitespace) input


-- | Parses a string that contains a sequence of statements.
parseStmts :: String -> [Stmt]
parseStmts input = parse (stmts <+-> whitespace) input


-- | Parses a whole piq program.
parseProgram :: String -> Program
parseProgram input = parse (program <+-> whitespace) input


-- | Reads and parses a piq program from a file.
parseProgramFile :: FilePath -> IO Program
parseProgramFile filename = parseFile (program <+-> whitespace) filename
