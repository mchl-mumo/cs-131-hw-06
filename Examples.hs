{-# OPTIONS_GHC -Wno-unused-imports #-}
{-|
Module       : Examples
Description  : Example piq programs as abstract syntax, and a convenient way
               to start GHCI.

**EXAMPLES.** `ghci Examples.hs` loads everything you need in GHCI: your
parser, the parser library, the provided compiler and pretty-printer, and the
examples below.

The examples are:
  * last week's example programs (`part2Centred` ... `part7Showcase`), which the
    round-trip tests print with the pretty-printer and parse back;
  * the abstract syntax of some of the programs in `programs/`, which the
    pipeline tests compare with what your parser reads from those files.
-}

module Examples where

import ParserCombinators   -- for experimenting with the parser library (Part 0)
import PiqAST
import PiqEvaluation
import PiqParser
import PiqPretty
import Python

import System.Directory   (makeAbsolute)
import System.Environment (lookupEnv)
import System.IO          (hFlush, stdout)
import System.Process     (rawSystem)


--------------------------------------------------------------------------------
-- Helpers for GHCI
--------------------------------------------------------------------------------

-- | Parses piq source code and compiles it: the whole pipeline, as a list of
--   Python lines
compileSource :: String -> [String]
compileSource source = compileProgram (parseProgram source)


-- | Parses and compiles piq source code, and prints the Python lines
showSource :: String -> IO ()
showSource source = mapM_ putStrLn (compileSource source)


-- | Compiles a program (given as abstract syntax) with the provided compiler,
--   writes python/<name>.py, and draws it with the mock plotter into
--   python/<name>.png. This works before your parser does.
previewProgram :: String -> Program -> IO ()
previewProgram fileName prog =
    do runtime <- makeAbsolute "python"
       emitPython runtime ("python/" ++ fileName ++ ".py") (compileProgram prog)
       fromEnvironment <- lookupEnv "PIQ_PYTHON"
       let python = maybe "python3" id fromEnvironment
       pyFile  <- makeAbsolute ("python/" ++ fileName ++ ".py")
       pngFile <- makeAbsolute ("python/" ++ fileName ++ ".png")
       hFlush stdout
       _ <- rawSystem python [pyFile, "--nowindow", "--out", pngFile]
       putStrLn ("Preview: python/" ++ fileName ++ ".png")


-- | Prints a program the way the pretty-printer writes it
showPretty :: Program -> IO ()
showPretty prog = putStr (prettyProgram prog)


--------------------------------------------------------------------------------
-- The programs in programs/
--------------------------------------------------------------------------------

-- | programs/hello.piq
helloProgram :: Program
helloProgram = Program [] [Square (Num 40), Circle (Num 20), Dot]


-- | programs/example.piq: three targets on a line
exampleProgram :: Program
exampleProgram =
    Program
        [ ProcDef "target" ["r"]
            [ For "k" (Num 1) (Num 3)
                [ Circle (Div (Mul (Var "k") (Var "r")) (Num 3)) ]
            , Dot
            ]
        ]
        [ Move Lt (Num 60)
        , For "i" (Num 1) (Num 3)
            [ Call "target" [Add (Num 10) (Mul (Var "i") (Num 5))]
            , Move Rt (Num 60)
            ]
        , Move Lt (Num 180)
        , Move Dn (Num 40)
        , Line Rt (Num 120)
        ]


-- | programs/spec_candidate.piq: a sample program from the language's design
specCandidate :: Program
specCandidate =
    Program
        [ ProcDef "boxes" ["size", "gap"]
            [ Square (Var "size")
            , Move Rt (Add (Var "size") (Var "gap"))
            , Square (Var "size")
            ]
        ]
        [ Assign "x" (Num 20)
        , Assign "y" (Mul (Var "x") (Num 2))
        , Dot
        , Square (Var "x")
        , Rectangle (Num 30) (Num 10)
        , Circle (Div (Var "x") (Num 2))
        , Move Rt (Num 15)
        , Move Up (Num 1)
        , Move Dn (Add (Var "x") (Num 5))
        , Line Lt (Num 10)
        , Line Rt (Num 1)
        , For "i" (Num 1) (Num 5)
            [ Square (Mul (Var "i") (Num 5))
            , Move Rt (Num 10)
            ]
        , Call "boxes" [Num 20, Num 5]
        ]


--------------------------------------------------------------------------------
-- Last week's example programs
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- From Part 2: dots, moves, lines, squares, rectangles
--------------------------------------------------------------------------------

-- | Nested closed shapes around one center. If centering works, they share a
--   center point, and the dot sits exactly in the middle.
--   Expected: squares of 80, 60, 40 mm, a wide 100x20 and a tall 20x100
--   rectangle crossing them, all centred on one dot.
part2Centred :: [Stmt]
part2Centred =
    [ Square (Num 80)
    , Square (Num 60)
    , Square (Num 40)
    , Rectangle (Num 100) (Num 20)
    , Rectangle (Num 20) (Num 100)
    , Dot
    ]


-- | A staircase climbing to the upper right. Checks the direction of each
--   move/line and that "up" really goes toward the top of the page.
--   Expected: five 20 mm steps rising to the right, then a line back down to
--   the starting height and back left, closing the outline.
part2Staircase :: [Stmt]
part2Staircase =
    concat (replicate 5 [Line Rt (Num 20), Line Up (Num 20)])
    ++ [ Line Dn (Num 100), Line Lt (Num 100) ]


-- | A row of shapes separated by moves (which must not draw).
--   Expected, left to right: a 30 mm square, a 50x20 rectangle, a dot, and a
--   20x50 rectangle, spaced 60 mm apart, with no lines between them.
part2Row :: [Stmt]
part2Row =
    [ Move Lt (Num 90)
    , Square (Num 30)
    , Move Rt (Num 60)
    , Rectangle (Num 50) (Num 20)
    , Move Rt (Num 60)
    , Dot
    , Move Rt (Num 60)
    , Rectangle (Num 20) (Num 50)
    ]


-- | A 5x5 grid of dots, 10 mm apart. Checks that dots show up and that moves
--   don't draw.
part2DotGrid :: [Stmt]
part2DotGrid = concat (replicate 5 rowOfDots)
    where rowOfDots = concat (replicate 5 [Dot, Move Rt (Num 10)])
                      ++ [Move Lt (Num 50), Move Dn (Num 10)]


--------------------------------------------------------------------------------
-- From Part 2: sizes computed by arithmetic
--------------------------------------------------------------------------------

-- | Sizes and distances computed by arithmetic, including fractions and a
--   negative distance (which goes the opposite way).
--   Expected: a 30 mm square at the start; 45 mm to its right, a 30x10
--   rectangle; and a 25 mm vertical line through the rectangle's centre,
--   starting 22.5 mm below it and ending 2.5 mm above it.
part2Exprs :: [Stmt]
part2Exprs =
    [ Square (Sub (Num 40) (Mul (Num 2) (Num 5)))              -- 30
    , Move Lt (Num (-45))                                      -- i.e. 45 to the right
    , Rectangle (Div (Num 60) (Num 2)) (Mul (Num 2.5) (Num 4)) -- 30 x 10
    , Move Dn (Num 22.5)
    , Line Up (Add (Num 2.5) (Mul (Num 3) (Num 7.5)))          -- 25
    ]


--------------------------------------------------------------------------------
-- From Part 3: circles
--------------------------------------------------------------------------------

-- | Concentric circles. Expected: circles of radius 10, 20 and 40 mm around
--   one center dot, with smooth-looking outlines.
part3Concentric :: [Stmt]
part3Concentric =
    [ Circle (Num 10)
    , Circle (Num 20)
    , Circle (Num 40)
    , Dot
    ]


-- | A circle inside a square of the same width (the radius is half the side),
--   and a circle around a square. Expected: on the left, a 60 mm square with a
--   radius-30 circle touching all four sides; on the right, a 40 mm square
--   whose corners touch a circle of radius 20 * sqrt 2 (about 28.3 mm).
part3Inscribed :: [Stmt]
part3Inscribed =
    [ Move Lt (Num 50)
    , Square (Num 60)
    , Circle (Div (Num 60) (Num 2))
    , Move Rt (Num 100)
    , Square (Num 40)
    , Circle (Num 28.284271247461902)
    ]


-- | A circle in the middle of a row. If the circle did not return to its
--   center, the shapes after it would be out of line.
--   Expected: square, circle, rectangle, circle, in a straight row 50 mm apart,
--   with a horizontal line underneath from the first shape's center to the last.
part3Row :: [Stmt]
part3Row =
    [ Move Lt (Num 75)
    , Square (Num 30)
    , Move Rt (Num 50)
    , Circle (Num 15)
    , Move Rt (Num 50)
    , Rectangle (Num 30) (Num 20)
    , Move Rt (Num 50)
    , Circle (Num 10)
    , Move Dn (Num 25)
    , Line Lt (Num 150)
    ]


--------------------------------------------------------------------------------
-- From Part 4: variables and assignment
--------------------------------------------------------------------------------

-- | The example from the assignment, plus one more doubling.
--   Expected: three concentric squares of 10, 20 and 40 mm.
part4Doubling :: [Stmt]
part4Doubling =
    [ Assign "x" (Num 10)
    , Square (Var "x")
    , Assign "x" (Mul (Var "x") (Num 2))
    , Square (Var "x")
    , Assign "x" (Mul (Var "x") (Num 2))
    , Square (Var "x")
    ]


-- | A row of circles that grow while the gap between them also grows.
--   Expected, left to right: circles of radius 5, 10, 15 and 20 mm, their
--   centres 30, 40 and 50 mm apart, so neighbours never touch.
part4GrowingRow :: [Stmt]
part4GrowingRow =
    [ Assign "r" (Num 5)
    , Assign "gap" (Num 30)
    , Move Lt (Num 60)
    , Circle (Var "r")
    , Move Rt (Var "gap")
    , Assign "r" (Add (Var "r") (Num 5))
    , Assign "gap" (Add (Var "gap") (Num 10))
    , Circle (Var "r")
    , Move Rt (Var "gap")
    , Assign "r" (Add (Var "r") (Num 5))
    , Assign "gap" (Add (Var "gap") (Num 10))
    , Circle (Var "r")
    , Move Rt (Var "gap")
    , Assign "r" (Add (Var "r") (Num 5))
    , Circle (Var "r")
    ]


-- | A frame whose size is computed from other variables.
--   Expected: a 120x60 rectangle (width = 2 * height), a second rectangle
--   10 mm inside it on every side (100x40), and a line across the middle
--   from the left edge of the inner rectangle to its right edge.
part4Frame :: [Stmt]
part4Frame =
    [ Assign "height" (Num 60)
    , Assign "width" (Mul (Num 2) (Var "height"))
    , Assign "margin" (Num 10)
    , Rectangle (Var "width") (Var "height")
    , Rectangle (Sub (Var "width") (Mul (Num 2) (Var "margin")))
                (Sub (Var "height") (Mul (Num 2) (Var "margin")))
    , Move Lt (Sub (Div (Var "width") (Num 2)) (Var "margin"))
    , Line Rt (Sub (Var "width") (Mul (Num 2) (Var "margin")))
    ]


--------------------------------------------------------------------------------
-- From Part 5: loops
--------------------------------------------------------------------------------

-- | part2Staircase, written with a loop. It must generate exactly the same code.
part5Staircase :: [Stmt]
part5Staircase =
    [ For "step" (Num 1) (Num 5)
        [ Line Rt (Num 20)
        , Line Up (Num 20)
        ]
    , Line Dn (Num 100)
    , Line Lt (Num 100)
    ]


-- | part2DotGrid, written with nested loops. It must generate exactly the same code.
part5DotGrid :: [Stmt]
part5DotGrid =
    [ For "row" (Num 1) (Num 5)
        [ For "col" (Num 1) (Num 5)
            [ Dot
            , Move Rt (Num 10)
            ]
        , Move Lt (Num 50)
        , Move Dn (Num 10)
        ]
    ]


-- | A row of growing squares, and a target of growing circles above it.
--   Expected: five squares with sides 8, 16, 24, 32, 40 mm, centred 45 mm
--   apart; above the middle square, eight concentric circles, radius 5 to 40.
part5Growing :: [Stmt]
part5Growing =
    [ Move Lt (Num 90)
    , For "i" (Num 1) (Num 5)
        [ Square (Mul (Var "i") (Num 8))
        , Move Rt (Num 45)
        ]
    , Move Lt (Num 135)
    , Move Up (Num 70)
    , For "r" (Num 1) (Num 8)
        [ Circle (Mul (Var "r") (Num 5)) ]
    ]


-- | Three nested loops: a 3x3 grid of targets, each made of three rings.
--   The spacing comes from a variable. Expected: nine targets (circles of
--   radius 4, 8 and 12 mm) in 3 rows and 3 columns, 35 mm apart, centred on
--   the start.
part5Targets :: [Stmt]
part5Targets =
    [ Assign "spacing" (Num 35)
    , Move Lt (Var "spacing")
    , Move Up (Var "spacing")
    , For "row" (Num 1) (Num 3)
        [ For "col" (Num 1) (Num 3)
            [ For "ring" (Num 1) (Num 3)
                [ Circle (Mul (Var "ring") (Num 4)) ]
            , Move Rt (Var "spacing")
            ]
        , Move Lt (Mul (Num 3) (Var "spacing"))
        , Move Dn (Var "spacing")
        ]
    ]


--------------------------------------------------------------------------------
-- From Part 6: procedures
--------------------------------------------------------------------------------

-- | The spec's shadowing example:
--
--       x = 10
--       define foo(x) { x = x + 100; square x }
--       foo(20)
--       square x
--
--   Expected: two concentric squares, 120 mm (inside foo, x is the
--   parameter, 20, plus 100) and 10 mm (after the call, x is the caller's 10
--   again).
part6Shadowing :: Program
part6Shadowing =
    Program
        [ ProcDef "foo" ["x"]
            [ Assign "x" (Add (Var "x") (Num 100))
            , Square (Var "x")
            ]
        ]
        [ Assign "x" (Num 10)
        , Call "foo" [Num 20]
        , Square (Var "x")
        ]


-- | A procedure with two parameters, called from a loop.
--   Expected: five squares growing from 8 to 40 mm, each followed by a
--   10 mm gap, so their edges are exactly 10 mm apart.
part6Boxes :: Program
part6Boxes =
    Program
        [ ProcDef "box" ["size", "gap"]
            [ Move Rt (Div (Var "size") (Num 2))
            , Square (Var "size")
            , Move Rt (Add (Div (Var "size") (Num 2)) (Var "gap"))
            ]
        ]
        [ Move Lt (Num 80)
        , For "i" (Num 1) (Num 5)
            [ Call "box" [Mul (Var "i") (Num 8), Num 10] ]
        ]


-- | Procedures calling procedures, and a procedure containing a loop.
--   target(r) draws three rings (radius r/3, 2r/3, r) and a centre dot.
--   flower(r) draws a target with four more targets touching it (above,
--   below, left, right), and returns to its centre.
--   Expected: two flowers of five targets each; the left one (r = 15) is
--   centred 80 mm left of the start, the right one (r = 10) 80 mm right.
part6Flowers :: Program
part6Flowers =
    Program
        [ ProcDef "target" ["r"]
            [ For "k" (Num 1) (Num 3)
                [ Circle (Div (Mul (Var "k") (Var "r")) (Num 3)) ]
            , Dot
            ]
        , ProcDef "flower" ["r"]
            [ Assign "d" (Mul (Num 2) (Var "r"))
            , Call "target" [Var "r"]
            , Move Up (Var "d"),  Call "target" [Var "r"], Move Dn (Var "d")
            , Move Dn (Var "d"),  Call "target" [Var "r"], Move Up (Var "d")
            , Move Lt (Var "d"),  Call "target" [Var "r"], Move Rt (Var "d")
            , Move Rt (Var "d"),  Call "target" [Var "r"], Move Lt (Var "d")
            ]
        ]
        [ Move Lt (Num 80)
        , Call "flower" [Num 15]
        , Move Rt (Num 160)
        , Call "flower" [Num 10]
        ]


--------------------------------------------------------------------------------
-- From Part 7: complete Week 1 programs
--------------------------------------------------------------------------------

-- | The showcase: a night city, using every Week 1 feature.
--
--   window(w)   a square window with four panes (lines), centred on the
--               current position, which it returns to.
--   building(floors, cols, w)
--               a building standing on the current position (its bottom
--               centre), with floors * cols windows placed by nested loops;
--               its size is computed from its arguments. Returns to its
--               bottom centre.
--   sun(r)      a circle with four rays (lines), centred on the current
--               position, which it returns to.
--
--   Expected: a ground line 360 mm long, 80 mm below the start; four
--   buildings standing on it at x = -120, -60, 0 and 60 mm, with 6, 15, 8 and
--   8 windows; a sun of radius 18 at (120, 70); and two staggered rows of ten
--   stars near the top.
part7Showcase :: Program
part7Showcase =
    Program
        [ ProcDef "window" ["w"]
            [ Square (Var "w")
            , Move Lt (Div (Var "w") (Num 2)), Line Rt (Var "w"), Move Lt (Div (Var "w") (Num 2))
            , Move Dn (Div (Var "w") (Num 2)), Line Up (Var "w"), Move Dn (Div (Var "w") (Num 2))
            ]
        , ProcDef "building" ["floors", "cols", "w"]
            [ Assign "gap" (Div (Var "w") (Num 2))
            , Assign "step" (Add (Var "w") (Var "gap"))
            , Assign "width" (Add (Mul (Var "cols") (Var "step")) (Var "gap"))
            , Assign "height" (Add (Mul (Var "floors") (Var "step")) (Var "gap"))
            , Assign "inset" (Add (Var "gap") (Div (Var "w") (Num 2)))
            -- the outline, centred halfway up
            , Move Up (Div (Var "height") (Num 2))
            , Rectangle (Var "width") (Var "height")
            -- to the centre of the bottom-left window
            , Move Lt (Sub (Div (Var "width") (Num 2)) (Var "inset"))
            , Move Dn (Sub (Div (Var "height") (Num 2)) (Var "inset"))
            , For "floor" (Num 1) (Var "floors")
                [ For "col" (Num 1) (Var "cols")
                    [ Call "window" [Var "w"]
                    , Move Rt (Var "step")
                    ]
                , Move Lt (Mul (Var "cols") (Var "step"))
                , Move Up (Var "step")
                ]
            -- back to the bottom centre
            , Move Rt (Sub (Div (Var "width") (Num 2)) (Var "inset"))
            , Move Dn (Add (Mul (Var "floors") (Var "step")) (Var "inset"))
            ]
        , ProcDef "sun" ["r"]
            [ Circle (Var "r")
            , Assign "gap" (Num 3)
            , Assign "ray" (Num 10)
            , Assign "far" (Add (Var "r") (Add (Var "gap") (Var "ray")))
            , Move Up (Add (Var "r") (Var "gap")), Line Up (Var "ray"), Move Dn (Var "far")
            , Move Dn (Add (Var "r") (Var "gap")), Line Dn (Var "ray"), Move Up (Var "far")
            , Move Lt (Add (Var "r") (Var "gap")), Line Lt (Var "ray"), Move Rt (Var "far")
            , Move Rt (Add (Var "r") (Var "gap")), Line Rt (Var "ray"), Move Lt (Var "far")
            ]
        ]
        [ -- the ground
          Move Dn (Num 80)
        , Move Lt (Num 180)
        , Line Rt (Num 360)
        -- the buildings, standing on the ground
        , Move Lt (Num 300)
        , Call "building" [Num 3, Num 2, Num 12]
        , Move Rt (Num 60)
        , Call "building" [Num 5, Num 3, Num 10]
        , Move Rt (Num 60)
        , Call "building" [Num 2, Num 4, Num 8]
        , Move Rt (Num 60)
        , Call "building" [Num 4, Num 2, Num 14]
        -- the sun, up and to the right
        , Move Up (Num 150)
        , Move Rt (Num 60)
        , Call "sun" [Num 18]
        -- two rows of stars; the second is shifted by half a gap
        , Assign "starGap" (Num 25)
        , Assign "starCount" (Num 10)
        , Move Lt (Num 290)
        , Move Up (Num 35)
        , For "row" (Num 1) (Num 2)
            [ For "star" (Num 1) (Var "starCount")
                [ Dot
                , Move Rt (Var "starGap")
                ]
            , Move Lt (Sub (Mul (Var "starCount") (Var "starGap")) (Div (Var "starGap") (Num 2)))
            , Move Dn (Num 12)
            ]
        ]


-- | A square spiral: each turn draws four lines, each a little longer than
--   the last. Each turn ends 4 mm left of and 4 mm below where it started, so
--   the rings of the spiral are 4 mm apart. Expected: 20 turns spiralling
--   outward from the start, ending 80 mm left of and 80 mm below it.
part7Spiral :: Program
part7Spiral =
    Program []
        [ For "i" (Num 1) (Num 20)
            [ Assign "a" (Mul (Var "i") (Num 8))
            , Line Rt (Var "a")
            , Line Up (Add (Var "a") (Num 2))
            , Line Lt (Add (Var "a") (Num 4))
            , Line Dn (Add (Var "a") (Num 6))
            ]
        ]


-- | A grid of tiles whose size depends on the row and column.
--   tile(s) is a square with its inscribed circle and a centre dot.
--   Expected: 4 rows of 6 tiles, 40 mm apart, centred on the start; tiles
--   grow from 14 mm (top left) to 30 mm (bottom right).
part7Tiles :: Program
part7Tiles =
    Program
        [ ProcDef "tile" ["s"]
            [ Square (Var "s")
            , Circle (Div (Var "s") (Num 2))
            , Dot
            ]
        ]
        [ Assign "spacing" (Num 40)
        , Move Lt (Mul (Num 2.5) (Var "spacing"))
        , Move Up (Mul (Num 1.5) (Var "spacing"))
        , For "row" (Num 1) (Num 4)
            [ For "col" (Num 1) (Num 6)
                [ Call "tile" [Add (Num 10) (Mul (Num 2) (Add (Var "row") (Var "col")))]
                , Move Rt (Var "spacing")
                ]
            , Move Lt (Mul (Num 6) (Var "spacing"))
            , Move Dn (Var "spacing")
            ]
        ]


--------------------------------------------------------------------------------
-- All of last week's examples, with their names
--------------------------------------------------------------------------------

lastWeeksExamples :: [(String, Program)]
lastWeeksExamples =
    [ ("part2Centred",    Program [] part2Centred)
    , ("part2Staircase",  Program [] part2Staircase)
    , ("part2Row",        Program [] part2Row)
    , ("part2DotGrid",    Program [] part2DotGrid)
    , ("part2Exprs",      Program [] part2Exprs)
    , ("part3Concentric", Program [] part3Concentric)
    , ("part3Inscribed",  Program [] part3Inscribed)
    , ("part3Row",        Program [] part3Row)
    , ("part4Doubling",   Program [] part4Doubling)
    , ("part4GrowingRow", Program [] part4GrowingRow)
    , ("part4Frame",      Program [] part4Frame)
    , ("part5Staircase",  Program [] part5Staircase)
    , ("part5DotGrid",    Program [] part5DotGrid)
    , ("part5Growing",    Program [] part5Growing)
    , ("part5Targets",    Program [] part5Targets)
    , ("part6Shadowing",  part6Shadowing)
    , ("part6Boxes",      part6Boxes)
    , ("part6Flowers",    part6Flowers)
    , ("part7Showcase",   part7Showcase)
    , ("part7Spiral",     part7Spiral)
    , ("part7Tiles",      part7Tiles)
    ]
