{-|
Module       : py2png
Description  : Draws a generated Python program with the mock plotter and
               saves the drawing as a PNG image.

    py2png garden.py                    writes garden.png
    py2png garden.py -o other.png       writes other.png

Build with `make` (the program goes in bin/).
-}

module Main where

import Tools
import System.Environment (getArgs)

main :: IO ()
main = reportErrors $
    do args <- getArgs
       parsed <- getToolArgs "py2png <file.py> [-o <output.png>]" args
       renderPng (fst parsed) (outputFile "png" parsed)
