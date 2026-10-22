{-|
Module       : piq2py
Description  : Compiles a piq program to a Python program.

    piq2py garden.piq                 writes garden.py
    piq2py garden.piq -o other.py     writes other.py

Run the result with python3 (--doplot only in the lab):
    python garden.py                          preview in a window
    python garden.py --nowindow --out x.png   save a preview image
    python garden.py --doplot                 draw on the real plotter

Build with `make` (the program goes in bin/).
-}

module Main where

import Tools
import System.Environment (getArgs)

main :: IO ()
main = reportErrors $
    do args <- getArgs
       parsed <- getToolArgs "piq2py <file.piq> [-o <output.py>]" args
       writePython (fst parsed) (outputFile "py" parsed)
