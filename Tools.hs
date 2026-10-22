{-|
Module       : Tools
Description  : Shared code for the command-line tools piq2py, py2png and
               piq2png: reading the command line, finding the project's
               files, and the two steps (piq -> Python, Python -> PNG).

**PROVIDED: DO NOT EDIT.** You do not need to read this file. It uses some
Haskell features (IO, running other programs) that the course doesn't cover.
-}

module Tools where

import PiqEvaluation (compileProgram)
import PiqParser     (parseProgramFile)
import Python         (emitPython)

import Control.Exception  (ErrorCall(..), IOException, catch)
import System.Directory   (canonicalizePath, doesFileExist, makeAbsolute)
import System.Environment (getExecutablePath, lookupEnv)
import System.Exit        (ExitCode(..), exitWith)
import System.FilePath    (replaceExtension, takeDirectory, (</>))
import System.IO          (hFlush, hPutStrLn, stderr, stdout)
import System.Process     (rawSystem)


--------------------------------------------------------------------------------
-- The command line
--------------------------------------------------------------------------------

-- | Reads a tool's arguments: one input file, and optionally "-o output"
--   (before or after the input file). Returns Nothing if the arguments don't
--   have that shape.
parseArgs :: [String] -> Maybe (FilePath, Maybe FilePath)
parseArgs [input]              = Just (input, Nothing)
parseArgs [input, "-o", output] = Just (input, Just output)
parseArgs ["-o", output, input] = Just (input, Just output)
parseArgs _                     = Nothing


-- | The output file: the one given with -o, or else the input file with a
--   new extension (for example "garden.piq" becomes "garden.py").
outputFile :: String -> (FilePath, Maybe FilePath) -> FilePath
outputFile _         (_, Just output) = output
outputFile extension (input, Nothing) = replaceExtension input extension


-- | Reads the arguments, or prints the usage message and stops.
getToolArgs :: String -> [String] -> IO (FilePath, Maybe FilePath)
getToolArgs usage args =
    case parseArgs args of
        Just parsed | not (isOption (fst parsed)) -> return parsed
        _ -> failWith ("usage: " ++ usage)
    where isOption arg = take 1 arg == "-"


-- | Runs a tool, reporting any error in the piq program (or any problem
--   running Python) as a short message instead of a Haskell backtrace.
reportErrors :: IO () -> IO ()
reportErrors tool = tool `catch` programError `catch` systemError
    where programError (ErrorCall message) = failWith ("error: " ++ message)
          systemError problem = failWith ("error: " ++ show (problem :: IOException))


-- | Prints a message to stderr and stops with a failure exit code.
failWith :: String -> IO a
failWith message =
    do hPutStrLn stderr message
       exitWith (ExitFailure 1)


--------------------------------------------------------------------------------
-- Where things are
--
-- The tools live in <project>/bin/, so the project folder is the folder above
-- the running program. The Python runtime is in <project>/python/.
--------------------------------------------------------------------------------

-- | The project folder (the parent of bin/)
projectDir :: IO FilePath
projectDir =
    do exe <- getExecutablePath
       canonicalizePath (takeDirectory exe </> "..")


-- | The folder containing plotter_runtime.py
runtimeDir :: IO FilePath
runtimeDir =
    do project <- projectDir
       return (project </> "python")


-- | The Python interpreter to run generated programs with: $PIQ_PYTHON if
--   it is set, otherwise python3. (Previews need matplotlib.)
pythonInterpreter :: IO FilePath
pythonInterpreter =
    do fromEnvironment <- lookupEnv "PIQ_PYTHON"
       case fromEnvironment of
           Just python -> return python
           Nothing     -> return "python3"


--------------------------------------------------------------------------------
-- The two steps
--------------------------------------------------------------------------------

-- | piq -> Python: parses and compiles a .piq file and writes the Python
--   program. A program with an error stops here, and no .py file is written.
writePython :: FilePath -> FilePath -> IO ()
writePython plotFile pyFile =
    do requireFile plotFile
       program <- parseProgramFile plotFile
       runtime <- runtimeDir
       emitPython runtime pyFile (compileProgram program)


-- | Python -> PNG: runs a generated Python program with the mock plotter,
--   without a window, saving the drawing as an image.
renderPng :: FilePath -> FilePath -> IO ()
renderPng pyFile pngFile =
    do requireFile pyFile
       python  <- pythonInterpreter
       pyPath  <- makeAbsolute pyFile
       pngPath <- makeAbsolute pngFile
       putStrLn ("Rendering " ++ pyFile ++ " to " ++ pngFile)
       hFlush stdout        -- so our messages appear before Python's
       exitCode <- rawSystem python [pyPath, "--nowindow", "--out", pngPath]
                       `catch` cannotRun python
       case exitCode of
           ExitSuccess   -> return ()
           ExitFailure _ -> failWith ("python failed while running " ++ pyFile ++ " (using " ++ python ++ ")")


-- | Stops with a clear message when the Python interpreter can't be run
cannotRun :: FilePath -> IOException -> IO ExitCode
cannotRun python _ =
    failWith ("error: cannot run " ++ python ++ "\n"
              ++ "(is Python 3 installed? set PIQ_PYTHON to your Python, e.g. /usr/bin/python3)")


-- | Stops with a clear message if a file doesn't exist
requireFile :: FilePath -> IO ()
requireFile file =
    do exists <- doesFileExist file
       if exists then return () else failWith ("no such file: " ++ file)
