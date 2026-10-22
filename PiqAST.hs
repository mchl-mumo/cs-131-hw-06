{-|
Module       : PiqAST
Description  : Abstract syntax for the piq pen-plotter language.
-}

module PiqAST where

-- | Variable names
type Name = String

-- | Arithmetic expressions. Every value in the language is a number.
data Expr = Num Double       -- ^ a numeric literal
          | Var Name         -- ^ a variable reference
          | Add Expr Expr    -- ^ e1 + e2
          | Sub Expr Expr    -- ^ e1 - e2
          | Mul Expr Expr    -- ^ e1 * e2
          | Div Expr Expr    -- ^ e1 / e2
            deriving (Eq, Show)

-- | Page-relative directions. There is no heading: "up" always means toward
--   the top of the page.
data Direction = Lt | Rt | Up | Dn
                 deriving (Eq, Show)

-- | Statements.
--
--   Closed shapes (dot, square, rectangle, circle) are centered on the current
--   position and leave it unchanged. Moves and lines change the current
--   position.
data Stmt = Assign Name Expr          -- ^ give a variable a (new) value
          | Dot                      -- ^ a single dot at the current position
          | Square Expr              -- ^ square with the given side length
          | Rectangle Expr Expr      -- ^ rectangle with the given width and height
          | Circle Expr              -- ^ circle with the given radius
          | Move Direction Expr      -- ^ travel without drawing
          | Line Direction Expr      -- ^ travel while drawing
          | For Name Expr Expr [Stmt] -- ^ for name from start to end { body }
          | Call Name [Expr]         -- ^ run a procedure with the given arguments
            deriving (Eq, Show)

-- | A procedure definition: its name, its parameter names, and its body.
--   Procedures are defined only at the top level of a program.
data ProcDef = ProcDef Name [Name] [Stmt]
               deriving (Eq, Show)

-- | A whole program: procedure definitions, then the statements to run.
data Program = Program [ProcDef] [Stmt]
               deriving (Eq, Show)
