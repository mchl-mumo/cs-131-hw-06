# piq parser (assignment starter)

> **⚠️ Finish and submit HW 5 before you open this repo.** `PiqEvaluation.hs` here is a complete, working solution
> to HW 5's compiler. Don't open, copy, or clone this repository until you (and your partner, if any) have
> completed and submitted HW 5. On Gradescope you'll confirm this with a checkbox when you submit HW 6.
> Full instructions: <https://www.cs.hmc.edu/~bang/cs131/assignments/hw06/>

**piq** is a tiny drawing language for a pen plotter. Last week you compiled piq abstract syntax into Python. In this
assignment you write, in Haskell with parser combinators, the **parser** that turns piq source code (`.piq` files)
into that abstract syntax. A complete compiler is provided, so once your parser works, `.piq` files become drawings:
first as preview pictures, and in the lab on a real Bantam Tools NextDraw plotter.

**The full handout is [ASSIGNMENT.md](ASSIGNMENT.md).** Work through it from the top. The language itself is
described in [SYNTAX.md](SYNTAX.md).

## Required software
- **GHC** with `ghci` and `runghc`, and the **hspec** test library (including `hspec-discover`);
- **Python 3 with matplotlib**, for preview pictures (`python3 -c "import matplotlib"` should print nothing).
  If your Python isn't called `python3`, set `PIQ_PYTHON` to its path.

## Quick start
From this folder:
```
make test             # run all the tests (many fail until you implement the TODOs)
ghci Examples.hs      # explore in GHCI; see ASSIGNMENT.md, Part 0
```
Other commands:

- `make part1` … `make part10` run one part's tests;
- `make` builds the tools `bin/piq2py`, `bin/py2png` and `bin/piq2png`, which are useful once your parser works;
- `make clean` removes generated files.

The file you edit is `PiqParser.hs`. Everything you need to fill in is marked `-- TODO (Part N)`.
