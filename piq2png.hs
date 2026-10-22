{-|
Module       : piq2png
Description  : Compiles a piq program to Python and draws it as a PNG image:
               piq2py followed by py2png. The Python program is kept, next
               to the image, so it can also be sent to the real plotter.

    piq2png garden.piq                writes garden.py and garden.png
    piq2png garden.piq -o other.png   writes other.py and other.png

Build with `make` (the program goes in bin/).
-}

module Main where

import Tools
import System.Environment (getArgs)
import System.FilePath    (replaceExtension)

main :: IO ()
main = reportErrors $
    do args <- getArgs
       parsed <- getToolArgs "piq2png <file.piq> [-o <output.png>]" args
       let pngFile = outputFile "png" parsed
           pyFile  = replaceExtension pngFile "py"
       writePython (fst parsed) pyFile
       renderPng pyFile pngFile
