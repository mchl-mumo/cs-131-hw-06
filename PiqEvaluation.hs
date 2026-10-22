{-|
Module       : PiqEvaluation
Description  : Evaluates piq expressions and compiles piq programs into
               primitive Python pen-plotter commands.

**PROVIDED: DO NOT EDIT.**

This file is provided. It is one possible solution to last week's compiler
assignment. You do not need to modify or understand every detail of it to
complete this week's work: this week you write the parser that produces the
abstract syntax this compiler consumes.

(You may replace this file with your own Assignment 1 implementation if you
want, but you do not need to. The supplied compiler lets you work on parsing
independently of any bugs that may remain in your first assignment.)
-}

module PiqEvaluation where

import           PiqAST
import           Python

import qualified Data.Map as Map


--------------------------------------------------------------------------------
-- Environments
--
-- An environment associates each variable name with its current value.
-- We use Data.Map, a lookup table implemented as a balanced binary tree.
-- Like every Haskell value it is immutable: "updating" an environment
-- builds a new environment and leaves the old one unchanged.
--
-- You should not need Data.Map directly. Use these helpers instead.
--------------------------------------------------------------------------------

-- | Maps variable names to their values
type Env = Map.Map Name Double


-- | An environment with no variables in it
emptyEnv :: Env
emptyEnv = Map.empty


-- | Looks up the value of a variable. Using a variable that has never been
--   assigned is an error in the piq program.
lookupVar :: Name -> Env -> Double
lookupVar name env =
    case Map.lookup name env of
        Just value -> value
        Nothing    -> error ("undefined variable: " ++ name)


-- | Returns a new environment in which the variable has the given value,
--   whether or not the variable already had a value.
assignVar :: Name -> Double -> Env -> Env
assignVar name value env = Map.insert name value env


-- | The variable's current value, if it has one. Used to remember a value
--   before it is temporarily replaced, so that restoreVar can put it back.
saveVar :: Name -> Env -> Maybe Double
saveVar name env = Map.lookup name env


-- | Puts back what saveVar remembered: the old value if there was one, and
--   otherwise removes the variable entirely.
restoreVar :: Name -> Maybe Double -> Env -> Env
restoreVar name (Just value) env = Map.insert name value env
restoreVar name Nothing      env = Map.delete name env


--------------------------------------------------------------------------------
-- Procedure environments
--
-- A procedure environment is a lookup table from procedure names to their
-- definitions. It is built once, from all of the program's definitions, and
-- never changes while the program is compiled.
--------------------------------------------------------------------------------

-- | Maps procedure names to their definitions
type ProcEnv = Map.Map Name ProcDef


-- | A procedure environment with no procedures in it
emptyProcEnv :: ProcEnv
emptyProcEnv = Map.empty


-- | Builds the procedure environment for a program's definitions. Defining
--   two procedures with the same name is an error.
makeProcEnv :: [ProcDef] -> ProcEnv
makeProcEnv [] = emptyProcEnv
makeProcEnv (ProcDef name params body : defs)
    | Map.member name rest = error ("duplicate procedure: " ++ name)
    | otherwise            = Map.insert name (ProcDef name params body) rest
    where rest = makeProcEnv defs


-- | Looks up a procedure's definition. Calling a procedure that was never
--   defined is an error in the piq program.
lookupProc :: Name -> ProcEnv -> ProcDef
lookupProc name procs =
    case Map.lookup name procs of
        Just def -> def
        Nothing  -> error ("unknown procedure: " ++ name)


--------------------------------------------------------------------------------
-- Expression evaluation
--------------------------------------------------------------------------------

-- | Evaluates an expression, using the environment for the values of its
--   variables.
eval :: Env -> Expr -> Double
eval _   (Num n)     = n
eval env (Var name)  = lookupVar name env
eval env (Add e1 e2) = eval env e1 + eval env e2
eval env (Sub e1 e2) = eval env e1 - eval env e2
eval env (Mul e1 e2) = eval env e1 * eval env e2
eval env (Div e1 e2)
    -- Haskell would quietly produce Infinity or NaN here. We report the
    -- error instead, so that bad numbers never reach the plotter.
    | denominator == 0 = error "division by zero"
    | otherwise        = eval env e1 / denominator
    where denominator = eval env e2


--------------------------------------------------------------------------------
-- Compiling statements
--
-- The compiler turns each statement into a list of lines of Python code.
-- It keeps one promise about the pen:
--
--     Between statements, the pen is always up.
--
-- So every statement that lowers the pen raises it again before it ends.
-- Some pen_up() calls are redundant (for example, a move always raises the
-- pen first, even though it is already up). That is fine: it keeps each
-- statement's code self-contained.
--
-- Coordinates are in millimetres, with positive x to the right and positive
-- y toward the top of the page.
--------------------------------------------------------------------------------

-- | Compiles a whole program. The procedure environment is built from the
--   program's definitions, and the statements are compiled starting with no
--   variables defined. Defining a procedure generates no code by itself; only
--   calling it does.
compileProgram :: Program -> [String]
compileProgram (Program defs stmts) =
    -- `seq` builds the whole procedure environment first, so that a duplicate
    -- procedure name is reported even if that procedure is never called.
    procs `seq` snd (compileStmts procs emptyEnv stmts)
    where procs = makeProcEnv defs


-- | Compiles one statement. Returns the environment afterward and the Python
--   code for the statement. Assignments change the environment but produce no
--   code; drawing statements produce code but leave the environment alone.
--   The procedure environment is passed along unchanged, for calls.
compileStmt :: ProcEnv -> Env -> Stmt -> (Env, [String])
compileStmt _ env (Assign name expr) =
    -- Haskell is lazy: without `seq`, the value would not be computed until
    -- some later statement used the variable, so a bad assignment such as
    -- x = 1 / 0 would go unnoticed if x were never used. `seq` computes the
    -- value first, so the error is reported right here.
    value `seq` (assignVar name value env, [])
    where value = eval env expr
compileStmt _ env Dot                 = (env, dotCode)
compileStmt _ env (Square side)       = (env, squareCode (eval env side))
compileStmt _ env (Rectangle wid ht)  = (env, rectangleCode (eval env wid) (eval env ht))
compileStmt _ env (Circle radius)     = (env, circleCode (eval env radius))
compileStmt _ env (Move dir distance) = (env, moveCode dir (eval env distance))
compileStmt _ env (Line dir distance) = (env, lineCode dir (eval env distance))
compileStmt procs env (For var from to body) = (restoreVar var saved loopEnv, code)
    where
        -- The bounds are evaluated once, before the loop starts, in the
        -- environment from before the loop.
        start = toLoopBound (eval env from)
        end   = toLoopBound (eval env to)
        -- The loop variable is local to the loop: remember what it was
        -- before, and put that back afterwards. Other variables assigned in
        -- the body keep their new values.
        saved = saveVar var env
        (loopEnv, code) = compileLoop procs var [start .. end] env body
-- A call compiles the procedure's body right here, in place of the call.
-- NOTE: Recursive procedure calls (a procedure that calls itself, directly or
-- through other procedures) are invalid piq programs. The compiler does not
-- check for them; compiling one never finishes.
compileStmt procs env (Call name args)
    | length params /= length args =
        error ("procedure " ++ name ++ " expects " ++ show (length params)
               ++ " arguments, got " ++ show (length args))
    -- The body's environment is thrown away: only its code is kept, and the
    -- caller carries on with exactly the environment it had before the call.
    | otherwise = forceValues argValues (env, bodyCode)
    where
        ProcDef _ params body = lookupProc name procs
        -- Arguments are evaluated in the caller's environment, all of them
        -- before any parameter is bound.
        argValues = map (eval env) args
        -- The procedure starts from the caller's environment, with each
        -- parameter bound to its argument's value (hiding any caller
        -- variable with the same name).
        localEnv = bindParams params argValues env
        (_, bodyCode) = compileStmts procs localEnv body


-- | Binds each parameter name to the matching argument value
bindParams :: [Name] -> [Double] -> Env -> Env
bindParams (param : params) (value : values) env = bindParams params values (assignVar param value env)
bindParams _                _                env = env


-- | Computes every value in the list before returning the result. (Like the
--   `seq` for assignments: without it, an argument such as 1 / 0 would go
--   unnoticed if the procedure never used that parameter.)
forceValues :: [Double] -> result -> result
forceValues []               result = result
forceValues (value : values) result = value `seq` forceValues values result


-- | Compiles a sequence of statements, one after another. Each statement is
--   compiled in the environment left by the statement before it, so an
--   assignment affects every statement that follows it. Returns the
--   environment after the last statement, and all of the code in order.
compileStmts :: ProcEnv -> Env -> [Stmt] -> (Env, [String])
compileStmts _     env []             = (env, [])
compileStmts procs env (stmt : stmts) = (finalEnv, firstCode ++ restCode)
    where (nextEnv, firstCode) = compileStmt procs env stmt
          (finalEnv, restCode) = compileStmts procs nextEnv stmts


-- | Compiles a loop body once for each value of the loop variable, in order.
--   Each iteration starts from the environment the previous iteration left,
--   with the loop variable set to the next value. An empty list of values
--   (a loop whose start is after its end) compiles the body zero times.
compileLoop :: ProcEnv -> Name -> [Int] -> Env -> [Stmt] -> (Env, [String])
compileLoop _     _   []               env _    = (env, [])
compileLoop procs var (value : values) env body = (finalEnv, bodyCode ++ restCode)
    where (afterBody, bodyCode) = compileStmts procs (assignVar var (fromIntegral value) env) body
          (finalEnv, restCode)  = compileLoop procs var values afterBody body


-- | Checks that a loop bound is a whole number and converts it to an Int.
toLoopBound :: Double -> Int
toLoopBound bound
    | fromIntegral wholeBound == bound = wholeBound
    | otherwise                        = error ("non-integral loop bound: " ++ show bound)
    where wholeBound = round bound


-- | How far a trip of the given distance in the given direction travels,
--   as (dx, dy).
offset :: Direction -> Double -> (Double, Double)
offset Rt distance = (distance, 0)
offset Lt distance = (-distance, 0)
offset Up distance = (0, distance)
offset Dn distance = (0, -distance)


-- | A dot: touch the pen to the paper at the current position.
dotCode :: [String]
dotCode = [penDown, penUp]


-- | Travel without drawing.
moveCode :: Direction -> Double -> [String]
moveCode dir distance = [penUp, moveRel dx dy]
    where (dx, dy) = offset dir distance


-- | Draw a line; the current position ends up at the far end of the line.
lineCode :: Direction -> Double -> [String]
lineCode dir distance = [penDown, moveRel dx dy, penUp]
    where (dx, dy) = offset dir distance


-- | A square centered on the current position: go to the bottom-left
--   corner, draw the four sides counterclockwise, then come back to the
--   center.
squareCode :: Double -> [String]
squareCode side =
    [ penUp
    , moveRel (-half) (-half)     -- center to bottom-left corner
    , penDown
    , moveRel side 0              -- bottom side
    , moveRel 0 side              -- right side
    , moveRel (-side) 0           -- top side
    , moveRel 0 (-side)           -- left side
    , penUp
    , moveRel half half           -- bottom-left corner back to center
    ]
    where half = side / 2


-- | A rectangle centered on the current position. Just like a square, except
--   that the width and height can differ.
rectangleCode :: Double -> Double -> [String]
rectangleCode wid ht =
    [ penUp
    , moveRel (-halfWid) (-halfHt)
    , penDown
    , moveRel wid 0
    , moveRel 0 ht
    , moveRel (-wid) 0
    , moveRel 0 (-ht)
    , penUp
    , moveRel halfWid halfHt
    ]
    where halfWid = wid / 2
          halfHt  = ht / 2


-- | How many straight segments make up a circle. With 36 (10 degrees each),
--   the segments stray from the true circle by at most about 0.4% of the
--   radius: 0.4 mm on a circle of radius 100 mm.
circleSegments :: Int
circleSegments = 36


-- | A circle centered on the current position, approximated by straight
--   segments. Point k of the circle is at angle 2*pi*k/circleSegments, at
--   (radius * cos angle, radius * sin angle) relative to the center. We start
--   at point 0 (the rightmost point) and step from each point to the next,
--   counterclockwise, until we are back at point 0.
--
--   Each step is computed from the two points' positions relative to the
--   center, not by adding onto the previous step, so rounding errors cannot
--   pile up: the path really does end where it started.
circleCode :: Double -> [String]
circleCode radius =
    [penUp, moveRel radius 0, penDown]           -- center to the rightmost point
    ++ map step [0 .. circleSegments - 1]        -- around the circle
    ++ [penUp, moveRel (-radius) 0]              -- rightmost point back to the center
    where
        step k  = moveRel (x (k + 1) - x k) (y (k + 1) - y k)
        x k     = radius * cos (angle k)
        y k     = radius * sin (angle k)
        angle k = 2 * pi * fromIntegral k / fromIntegral circleSegments
