# Assignment: the piq parser (source code → abstract syntax)

Last week you wrote a compiler that turns piq programs, written as Haskell abstract syntax, into Python programs
for a pen plotter. This week you write the **parser**: the part that reads piq **source code**, text like

```
define box(size, gap) {
    square size
    move right size + gap
}
for i from 1 to 5 {
    box(i * 8, 10)
}
```

and recovers its structure as abstract syntax:

```haskell
Program [ProcDef "box" ["size","gap"] [Square (Var "size"), Move Rt (Add (Var "size") (Var "gap"))]]
        [For "i" (Num 1.0) (Num 5.0) [Call "box" [Mul (Var "i") (Num 8.0), Num 10.0]]]
```

With your parser, piq becomes a real language: you'll be able to write drawings in `.piq` files and turn them into
pictures (and plotter drawings) with one command.

```
    programs/example.piq   (source code)
        |
        |  YOUR WORK: PiqParser.hs
        v
    AST
        |
        |  PROVIDED: a complete compiler (last week's assignment)
        v
    Python  ──>  preview picture  ──>  the real pen plotter (in the lab)
```

As last week, the work is split into **many small steps**, and every step ends with a **Check your work** box
saying exactly what to type and what you should see.

---

## Contents
- [Learning goals](#learning-goals)
- [Getting started](#getting-started)
- [The files](#the-files)
- [How to work: GHCI, tests, the tools](#how-to-work-ghci-tests-the-tools)
- [The provided compiler](#the-provided-compiler)
- [The parser library: a cheat sheet](#the-parser-library-a-cheat-sheet)
- [Part 0: orientation](#part-0-orientation)
- [Part 1: names and keywords](#part-1-names-and-keywords)
- [Part 2: atoms](#part-2-atoms)
- [Part 3: precedence and associativity](#part-3-precedence-and-associativity)
- [Part 4: basic statements](#part-4-basic-statements)
- [Part 5: statement sequences and blocks](#part-5-statement-sequences-and-blocks)
- [Part 6: loops](#part-6-loops)
- [Part 7: procedure calls](#part-7-procedure-calls)
- [Part 8: procedure definitions](#part-8-procedure-definitions)
- [Part 9: whole programs](#part-9-whole-programs)
- [Part 10: the whole pipeline](#part-10-the-whole-pipeline)
- [Common pitfalls](#common-pitfalls)
- [Final checklist](#final-checklist)
- [Submitting](#submitting)
- [Appendix: the real plotter](#appendix-the-real-plotter)

---

## Learning goals
By the end of this assignment you will have:

- read a **grammar** and turned each rule into a parser;
- used **parser combinators** to build big parsers out of small ones;
- handled **reserved words**, and seen why a keyword must be matched as a whole word;
- implemented operator **precedence** (`*` before `+`) and **left associativity** (`10 - 3 - 2` means `(10 - 3) - 2`);
- parsed statements, blocks, loops, procedure calls and definitions, and whole programs;
- checked your parser with **round trips**: printing an AST as source code and parsing it back gives the same AST;
- compiled real `.piq` files into drawings.

---

## Getting started
You need:

- **GHC** with `ghci` and `runghc`, and the **hspec** test library;
- **Python 3 with matplotlib**, for pictures. Check with `python3 -c "import matplotlib"`: no output means it
  works. If your Python has another name, set `PIQ_PYTHON`, e.g. `export PIQ_PYTHON=/usr/local/bin/python3`.

Everything in this handout is run **from the top folder of this repository**. Read `SYNTAX.md` now: it is the
exact description of what your parser must accept.

---

## The files
| File | What it is |
|---|---|
| `PiqParser.hs` | **YOU WILL EDIT.** The parser. Every place to fill in is marked `-- TODO (Part N)`. |
| `SYNTAX.md` | **PROVIDED.** The grammar of piq: exactly what the parser must accept. It also shows which parser handles which rule. |
| `ParserCombinators.hs`, `ParserBase.hs` | **PROVIDED: DO NOT EDIT.** The course's parser-combinator library. **You do not need to understand how these files are implemented.** You only use what `ParserCombinators` exports (see the [cheat sheet](#the-parser-library-a-cheat-sheet)). |
| `PiqAST.hs` | **PROVIDED: DO NOT EDIT.** The abstract syntax, the same as last week. |
| `PiqEvaluation.hs` | **PROVIDED: DO NOT EDIT.** A complete compiler (see [below](#the-provided-compiler)). |
| `PiqPretty.hs` | **PROVIDED: DO NOT EDIT.** The pretty-printer: abstract syntax back into source code. Used for round trips. |
| `Python.hs`, `Tools.hs`, `piq2py.hs`, `py2png.hs`, `piq2png.hs`, `python/` | **PROVIDED: DO NOT EDIT.** The Python side and the command-line tools. |
| `Makefile` | **PROVIDED.** `make` (build the tools), `make test`, `make part1` … `make part10`, `make clean`. |
| `test/*.hs` | **TESTS.** One module per group of parts (`NameSpec`, `ExprParserSpec`, `BasicStmtParserSpec`, `BlockParserSpec`, `ProcParserSpec`, `RoundTripSpec`, `PipelineSpec`). |
| `Examples.hs` | **EXAMPLES.** `ghci Examples.hs` loads everything. It also contains last week's example programs, the abstract syntax of the programs in `programs/`, and some GHCI helpers. |
| `programs/*.piq` | **EXAMPLES.** piq programs in source form. |

---

## How to work: GHCI, tests, the tools

### GHCI
```
$ ghci Examples.hs
```
This loads your parser, the parser library, the compiler and the pretty-printer. After editing `PiqParser.hs`,
type `:reload` (or `:r`).

When a parse fails, GHCI shows an exception. **The first line is the message**, starting with where in the input
the problem was (`<input>:line:column`):
```
ghci> parse number "x"
*** Exception: <input>:1:1 -- <num> expected
CallStack (from HasCallStack):
  error, called at ./ParserBase.hs:80:13 in main:ParserBase
```
If the parser's result is a **string**, GHCI has already printed the opening quote `"` when the error arrives, so you
see `"*** Exception: …`. That's just GHCI; the `"` isn't part of the message.

### Tests
| Command | Runs |
|---|---|
| `make test` | all the tests (the final check) |
| `make part1` … `make part10` | only one part's tests |
| `runghc -itest test/Spec.hs --match "Step 3.2"` | only one step's tests |

Each step below says which command to run and exactly what the last line should say.

**About tests that pass early:** many tests check that bad input is **rejected** (`"… is rejected"`). An
unfinished parser rejects everything, so those tests pass from the start. They become meaningful when your parser
starts accepting things: then they make sure it doesn't accept too much. The test summary for a step is only fully
meaningful once you've done that step.

### The tools
`make` builds three command-line tools into `bin/`. They need your parser, so they're most useful at the end
(Part 10):
```
bin/piq2py  file.piq [-o other.py]    piq source -> Python (default: file.py)
bin/py2png  file.py  [-o other.png]   Python -> picture, drawn by the mock plotter (default: file.png)
bin/piq2png file.piq [-o other.png]   both: file.py and file.png
```

---

## The provided compiler
`PiqEvaluation.hs` is **provided**. It is one possible solution to last week's compiler assignment. You do not need
to modify or understand every detail of it to complete this week's work.

You may replace it with your own Assignment 1 `PiqEvaluation.hs` if you want, but you don't need to. The supplied
compiler lets you work on parsing independently of any bugs that may remain in your first assignment.

---

## The parser library: a cheat sheet
A `Parser a` reads some input and produces a value of type `a`. `parse p "input"` runs parser `p` on the **whole**
input (it's an error if anything is left over). All of these skip whitespace (spaces, tabs, newlines) before what
they read.

| Combinator | Meaning | Example (in GHCI) → result |
|---|---|---|
| `number`, `double` | an integer / a decimal number | `parse double "2.5"` → `2.5` |
| `text "abc"` | exactly the characters `abc` | `parse (text "hello") "   hello"` → `"hello"` |
| `sym 'c'` | exactly the character `c` | used as a separator: `sym ','` |
| `identifier` | a letter followed by letters and digits | `parse identifier "size2"` → `"size2"` |
| `p <+> q` | `p` then `q`; the result is a **pair** | `parse (number <+> number) "3 4"` → `(3,4)` |
| `p <-+> q` | `p` then `q`; keep only **`q`**'s result | `parse (text "move" <-+> number) "move 5"` → `5` |
| `p <+-> q` | `p` then `q`; keep only **`p`**'s result | |
| `p <\|> q` | try `p`; if it fails, try `q` instead | `parse (text "a" <\|> text "b") "b"` → `"b"` |
| `p >>=: f` | run `p`, then apply the function `f` to its result | `parse (number >>=: (* 2)) "21"` → `42` |
| `p >>: v` | run `p`, then ignore its result and give `v` | `parse (text "yes" >>: True) "yes"` → `True` |
| `p <=> test` | run `p`, but **fail** unless its result passes `test` | see Part 1 |
| `many p` | `p` zero or more times; a list of results | `parse (many digit) "123"` → `"123"` |
| `sepBy p sep` | zero or more `p`s separated by `sep`s | `parse (sepBy number (sym ',')) "1, 2, 3"` → `[1,2,3]` |
| `parens p`, `braces p` | `p` inside `( )` / `{ }` | `parse (parens number) "( 7 )"` → `7` |
| `pfail` | always fails | the starting value of unfinished parsers |

**How they group.** `>>=:` and `>>:` bind **most loosely**, `<|>` binds more tightly, and `<+>`, `<-+>`, `<+->`
bind most tightly. So `keyword "circle" <-+> expr >>=: Circle` means "(keyword then expr), then apply `Circle`",
which is what you want. **But when you combine alternatives, put each one in parentheses**:
`(p1 >>=: f) <|> (p2 >>=: g)`. Without them, `p1 >>=: f <|> p2 >>=: g` would group the wrong way.

**Sequencing makes nested pairs:** `a <+> b <+> c` gives `((ra, rb), rc)`. A lambda with a matching pattern takes
it apart: `>>=: \((ra, rb), rc) -> …`. A pair result can also go straight to a two-argument function with
`uncurry`: `uncurry f (x, y) = f x y`.

---

## Part 0: orientation
Nothing to implement yet. Get to know the library, and the compiler you've been given.

### Step 0.1: the parser library
Start `ghci Examples.hs` and try the examples from the cheat sheet. Then try a parse that fails.

> **✅ Check your work (Step 0.1)**
> <!-- state: 0.0 -->
> ```
> ghci> parse number "42"
> 42
> ghci> parse (number <+> number) "3 4"
> (3,4)
> ghci> parse (text "move" <-+> number) "move 5"
> 5
> ghci> parse (number >>=: (* 2)) "21"
> 42
> ghci> parse (sepBy number (sym ',')) "1, 2, 3"
> [1,2,3]
> ghci> parse (identifier <=> (\w -> length w > 3)) "long"
> "long"
> ghci> parse number "x"
> *** Exception: <input>:1:1 -- <num> expected
> …
> ```

### Step 0.2: the provided compiler, and your starting point
The compiler works right away, on abstract syntax. `previewProgram` compiles an AST, writes `python/<name>.py`, and
draws `python/<name>.png`. `showPretty` prints an AST as source code; that's the language your parser will read.
And one parser already works: `parseExpr` can read a number.

> **✅ Check your work (Step 0.2)**
> <!-- state: 0.0 -->
> ```
> ghci> mapM_ putStrLn (compileProgram (Program [] [Dot]))
> pen_down()
> pen_up()
> ghci> previewProgram "hello" helloProgram
> Writing python/hello.py
> [nextdraw_backend] Using MOCK NextDraw (preview only)
> [mock_nextdraw] Saved preview to …/python/hello.png
> Preview: python/hello.png
> ghci> showPretty exampleProgram
> define target(r) {
>     for k from 1 to 3 {
>         circle ((k * r) / 3)
>     }
>     dot
> }
>
> move left 60
> for i from 1 to 3 {
>     target((10 + (i * 5)))
>     move right 60
> }
> move left 180
> move down 40
> line right 120
> ghci> parseExpr "42"
> Num 42.0
> ```
> `python/hello.png` shows a 40 mm square with a circle inside it and a dot at the centre. The pretty-printer
> puts parentheses around every operation (`circle ((k * r) / 3)`); your parser will accept both that and the
> simpler `circle k * r / 3` in `programs/example.piq`.
> ```
> $ runghc -itest test/Spec.hs --match "Step 2.1"
> 7 examples, 0 failures
> ```
> (Step 2.1 tests number parsing, which is provided.)

---

## Part 1: names and keywords
piq has **reserved words** (`dot`, `square`, …, `define`): they have a special meaning, so they can't be used as
names. Names are made of a letter followed by letters and digits, which is exactly what the library's
`identifier` reads.

### Why `text "dot"` is not good enough
To read the keyword `dot`, you might use `text "dot"`. But `text` only checks the **next three characters**. So given
the name `dotty`, it happily reads `dot` and leaves `ty` behind:

> **✅ Try this (no code to write)**
> <!-- state: 0.0 -->
> ```
> ghci> parse (text "dot" <+> identifier) "dotty"
> ("dot","ty")
> ```

So `dotty = 3` could be read as the statement `dot` followed by `ty = 3`, which is wrong. The fix: read a **whole
identifier**, then check that it's exactly the keyword.

### Step 1.1: `isReserved`
**Implement** `isReserved word`: is `word` one of `reservedWords` (provided)? One line with `elem`.

> **✅ Check your work (Step 1.1)**
> <!-- state: 1.1 -->
> ```
> ghci> isReserved "left"
> True
> ghci> isReserved "leftover"
> False
> ```
> ```
> $ runghc -itest test/Spec.hs --match "Step 1.1"
> 3 examples, 0 failures
> ```

### Step 1.2: `keyword`
**Implement** `keyword word`: read an `identifier`, and keep it only if it's exactly `word`. Use `<=>` with a small
test function (a lambda). `keyword "dot"` then accepts `dot` but rejects `dotty`, because `identifier` reads all of
`dotty`, and `"dotty"` isn't `"dot"`.

> **✅ Check your work (Step 1.2)**
> <!-- state: 1.2 -->
> ```
> ghci> parse (keyword "dot") "dot"
> "dot"
> ghci> parse (keyword "dot") "dotty"
> "*** Exception: <input>:1:6 -- No parse (via pfail)
> …
> ```
> ```
> $ runghc -itest test/Spec.hs --match "Step 1.2"
> 6 examples, 0 failures
> ```

### Step 1.3: `name`
**Implement** `name`: an `identifier` that is **not** reserved. Same idea as `keyword`, with a different test.

Now the provided `dot` statement works too, because it's `keyword "dot" >>: Dot`.

> **✅ Check your work (Step 1.3, and all of Part 1)**
> <!-- state: 1.3 -->
> ```
> ghci> parse name "dotty"
> "dotty"
> ghci> parse name "circle"
> "*** Exception: <input>:1:7 -- No parse (via pfail)
> …
> ghci> parseStmt "dot"
> Dot
> ```
> ```
> $ runghc -itest test/Spec.hs --match "Step 1.3"
> 10 examples, 0 failures
> $ make part1
> 19 examples, 0 failures
> ```

---

## Part 2: atoms
From here on, keep `SYNTAX.md` open. The grammar for expressions is

```
expr   ::= term   (("+" | "-") term)*
term   ::= factor (("*" | "/") factor)*
factor ::= number | name | "(" expr ")"
```

A **factor** is an atom: the smallest piece of an expression. `factor`'s number case is provided:
`double >>=: Num` reads a number and wraps it in the `Num` constructor.

For now `expr` and `term` are **placeholders**: `expr = term` and `term = factor`, so that expressions work at all.
You'll replace them in Part 3.

### Step 2.1: numbers (provided)
Already works: the tests passed in Part 0.

### Step 2.2: variables
**Add an alternative** to `factor`: a `name`, wrapped in `Var`. Add it with `<|>` **before** the `<???>` line (that
line only improves the error message).

> **✅ Check your work (Step 2.2)**
> <!-- state: 2.2 -->
> ```
> ghci> parseExpr "size"
> Var "size"
> ghci> parseExpr "dot"
> *** Exception: <input>:1:4 -- No parse (via pfail)
> …
> ```
> `dot` is rejected because it's reserved, not a name.
> ```
> $ runghc -itest test/Spec.hs --match "Step 2.2"
> 10 examples, 0 failures
> ```

### Step 2.3: parentheses
**Add a third alternative**: an `expr` inside parentheses (`parens`). Notice that `factor` uses `expr`, and `expr`
(through `term`) uses `factor`. That recursion is what lets expressions nest.

> **✅ Check your work (Step 2.3, and all of Part 2)**
> <!-- state: 2.3 -->
> ```
> ghci> parseExpr "((x))"
> Var "x"
> ghci> parseExpr "(1 + 2)"
> *** Exception: <input>:1:3 -- ')' expected
> …
> ```
> The second one fails for now, because there's no `+` yet (Part 3).
> ```
> $ runghc -itest test/Spec.hs --match "Step 2.3"
> 7 examples, 0 failures
> $ make part2
> 24 examples, 0 failures
> ```

---

## Part 3: precedence and associativity
Two rules decide what an expression means:

- **Precedence:** `*` and `/` bind more tightly than `+` and `-`. So `x + 5 * 2` means `x + (5 * 2)`:
  ```
  Add (Var "x") (Mul (Num 5) (Num 2))
  ```
- **Left associativity:** operators of the same level group **from the left**. So `10 - 3 - 2` means
  `(10 - 3) - 2` = 5, **not** `10 - (3 - 2)` = 9:
  ```
  Sub (Sub (Num 10) (Num 3)) (Num 2)
  ```

The grammar gets precedence from its **levels**: an `expr` is made of `term`s joined by `+`/`-`, and a `term` is
made of `factor`s joined by `*`/`/`. In `x + 5 * 2`, the `5 * 2` is one term, so the `*` happens "inside" the `+`.

Left associativity comes from how you **combine** the pieces. Reading `10 - 3 - 2` as "a first operand, then a list
of (operator, operand) pairs" gives

```
first operand:  Num 10
pairs:          [(Sub, Num 3), (Sub, Num 2)]
```

Combining **from the left** means: combine the first operand with the first pair, then combine *that result* with
the next pair, and so on.

### Step 3.1: `combineLeft`
**Implement** `combineLeft :: Expr -> [(Expr -> Expr -> Expr, Expr)] -> Expr`. The operators in the pairs are AST
**constructors** such as `Sub`, which are functions of two `Expr`s. Recursion on the list of pairs:

- no pairs: the result is the expression so far;
- a pair `(op, right)` followed by more pairs: combine the expression so far with `right` using `op`, and carry
  **that** on to the rest of the pairs.

> **✅ Check your work (Step 3.1)**
> <!-- state: 3.1 -->
> ```
> ghci> combineLeft (Num 10) [(Sub, Num 3), (Sub, Num 2)]
> Sub (Sub (Num 10.0) (Num 3.0)) (Num 2.0)
> ghci> combineLeft (Num 1) []
> Num 1.0
> ```
> ```
> $ runghc -itest test/Spec.hs --match "Step 3.1"
> 4 examples, 0 failures
> ```

### Step 3.2: terms: `mulOp` and `term`
**Implement** `mulOp`: a parser for `*` or `/` whose **result is the AST constructor** (`Mul` or `Div`). Two
alternatives, each "read the symbol, give the constructor" (`>>:`).

**Replace** the placeholder `term`, following its grammar rule: a `factor`, then **zero or more** (operator, factor)
pairs. Sequencing a `factor` with `many` of (`mulOp` then `factor`) produces a pair: the first factor, and a list of
(operator, factor) pairs. Those are exactly `combineLeft`'s two arguments; hand them over with `>>=:` and a lambda.

> **✅ Check your work (Step 3.2)**
> <!-- state: 3.2 -->
> ```
> ghci> parseExpr "8 / 4 / 2"
> Div (Div (Num 8.0) (Num 4.0)) (Num 2.0)
> ghci> parseExpr "2 * x"
> Mul (Num 2.0) (Var "x")
> ```
> ```
> $ runghc -itest test/Spec.hs --match "Step 3.2"
> 5 examples, 0 failures
> ```

### Step 3.3: expressions: `addOp` and `expr`
**Implement** `addOp` (`+`/`-`, giving `Add`/`Sub`) and **replace** the placeholder `expr` the same way, one level up:
`term`s joined by `addOp`.

> **✅ Check your work (Step 3.3)**
> <!-- state: 3.3 -->
> ```
> ghci> parseExpr "2 + 3 * 4"
> Add (Num 2.0) (Mul (Num 3.0) (Num 4.0))
> ghci> parseExpr "x + 5 * 2"
> Add (Var "x") (Mul (Num 5.0) (Num 2.0))
> ghci> parseExpr "10 - 3 - 2"
> Sub (Sub (Num 10.0) (Num 3.0)) (Num 2.0)
> ghci> parseExpr "(1 + 2) * 3"
> Mul (Add (Num 1.0) (Num 2.0)) (Num 3.0)
> ```
> ```
> $ runghc -itest test/Spec.hs --match "Step 3.3"
> 22 examples, 0 failures
> ```

### Step 3.4: round trips
The provided pretty-printer turns an AST back into source code. It puts parentheses around every operation, so its
output is unambiguous. For every expression `e`, **parsing the printed expression must give back `e` exactly**:

```
parseExpr (prettyExpr e) == e
```

This is a strong test: if your parser recovers the structure of what the printer wrote, precedence and grouping must
be right. Nothing new to write.

> **✅ Check your work (Step 3.4, and all of Part 3)**
> <!-- state: 3.3 -->
> ```
> ghci> prettyExpr (parseExpr "x + 5 * 2")
> "(x + (5 * 2))"
> ghci> parseExpr (prettyExpr (Sub (Num 10) (Sub (Num 3) (Num 2))))
> Sub (Num 10.0) (Sub (Num 3.0) (Num 2.0))
> ```
> ```
> $ runghc -itest test/Spec.hs --match "Step 3.4"
> 14 examples, 0 failures
> $ make part3
> 45 examples, 0 failures
> ```

---

## Part 4: basic statements
A statement is one of several kinds. The provided `stmt` tries each kind in turn:

```haskell
stmt = assignment <|> call <|> forLoop <|> dotStmt <|> squareStmt <|> rectangleStmt
       <|> circleStmt <|> moveStmt <|> lineStmt
```

Each unfinished one is `pfail` for now, so `stmt` already works for the kinds you've finished. Every statement
except assignment and call starts with its own keyword, which is why the keywords from Part 1 matter.

The provided example is `dotStmt = keyword "dot" >>: Dot`. It reads the keyword, then gives the constructor.

### Step 4.1: dot (provided)
Already works since Part 1.

> **✅ Check your work (Step 4.1)**
> <!-- state: 1.3 -->
> ```
> $ runghc -itest test/Spec.hs --match "Step 4.1"
> 4 examples, 0 failures
> ```

### Step 4.2: square, rectangle, circle
**Implement** `squareStmt`, `rectangleStmt`, `circleStmt`.

- `square EXPR`: the keyword, then an expression. Keep only the expression (`<-+>`) and apply `Square` to it (`>>=:`).
- `circle EXPR` works the same way.
- `rectangle EXPR EXPR`: two expressions, width then height. Sequencing them gives a pair, and `uncurry Rectangle`
  turns a pair into a `Rectangle`.

> **✅ Check your work (Step 4.2)**
> <!-- state: 4.2 -->
> ```
> ghci> parseStmt "square 20"
> Square (Num 20.0)
> ghci> parseStmt "rectangle w + 1 h * 2"
> Rectangle (Add (Var "w") (Num 1.0)) (Mul (Var "h") (Num 2.0))
> ghci> parseStmt "circle r / 2"
> Circle (Div (Var "r") (Num 2.0))
> ```
> In `rectangle w + 1 h * 2`, the first expression ends where it can't continue: after `w + 1`, the next token `h`
> isn't an operator.
> ```
> $ runghc -itest test/Spec.hs --match "Step 4.2"
> 18 examples, 0 failures
> ```
> One of the tests checks that `rectangle 30 -10` is **rejected**: `30 -10` reads as the single expression `30 - 10`,
> and then the height is missing. Programs write `rectangle 30 (-10)` instead.

### Step 4.3: directions, move, line
**Add** the other three alternatives to `direction` (`right`, `up`, `down`; `left` is provided), then implement
`moveStmt` and `lineStmt`: the keyword, a direction, an expression. The direction and the expression form a pair,
and `uncurry Move` turns that pair into a statement.

Distances are always required: `move right` without a number is an error.

> **✅ Check your work (Step 4.3)**
> <!-- state: 4.3 -->
> ```
> ghci> parse direction "up"
> Up
> ghci> parseStmt "move left 20"
> Move Lt (Num 20.0)
> ghci> parseStmt "line down 2.5"
> Line Dn (Num 2.5)
> ghci> parseStmt "move right"
> *** Exception: <input>:1:11 -- a number, a name, or ( expected
> …
> ```
> ```
> $ runghc -itest test/Spec.hs --match "Step 4.3"
> 17 examples, 0 failures
> ```

### Step 4.4: assignment
**Implement** `assignment`: `NAME = EXPR`. Keep the name and the expression, drop the `=` (`<+->` keeps the left
result), and build an `Assign`.

Because `name` never accepts a reserved word, `dotty = 3` is an assignment, and `dot = 1` is rejected.

> **✅ Check your work (Step 4.4)**
> <!-- state: 4.4 -->
> ```
> ghci> parseStmt "size = size * 2"
> Assign "size" (Mul (Var "size") (Num 2.0))
> ghci> parseStmt "dotty = 3"
> Assign "dotty" (Num 3.0)
> ```
> ```
> $ runghc -itest test/Spec.hs --match "Step 4.4"
> 14 examples, 0 failures
> ```

### Step 4.5: statement round trips
As in Step 3.4: every basic statement in last week's examples, printed and parsed back, must come out the same.

> **✅ Check your work (Step 4.5, and all of Part 4)**
> <!-- state: 4.4 -->
> ```
> ghci> prettyStmt (Rectangle (Num 30) (Num (-10)))
> "rectangle 30 (-10)"
> ghci> parseStmt (prettyStmt (Rectangle (Num 30) (Num (-10))))
> Rectangle (Num 30.0) (Num (-10.0))
> ```
> ```
> $ runghc -itest test/Spec.hs --match "Step 4.5"
> 1 example, 0 failures
> $ make part4
> 54 examples, 0 failures
> ```

---

## Part 5: statement sequences and blocks
**Newlines and semicolons are not statement terminators.** piq has no separators at all: whitespace, including
newlines, only separates tokens. A statement simply ends where its last part ends, so these mean the same thing:

```
x = 10               x = 10 square x x = x * 2 square x
square x
x = x * 2
square x
```

### Step 5.1: `stmts`
**Implement** `stmts`: zero or more statements. That's one library combinator.

> **✅ Check your work (Step 5.1)**
> <!-- state: 5.1 -->
> ```
> ghci> parseStmts "x = 10 square x x = x * 2 square x"
> [Assign "x" (Num 10.0),Square (Var "x"),Assign "x" (Mul (Var "x") (Num 2.0)),Square (Var "x")]
> ghci> parseStmts "dot\n  dot"
> [Dot,Dot]
> ghci> parseStmts ""
> []
> ```
> ```
> $ runghc -itest test/Spec.hs --match "Step 5.1"
> 13 examples, 0 failures
> ```
> One test compares with `text "dot"`, showing `dotty = 3` wrongly split into a dot and `ty = 3`. Your `keyword`
> is what prevents that.

### Step 5.2: `block`
**Implement** `block`: statements between braces. A block may be empty.

> **✅ Check your work (Step 5.2, and all of Part 5)**
> <!-- state: 5.2 -->
> ```
> ghci> parse block "{ dot square 3 }"
> [Dot,Square (Num 3.0)]
> ghci> parse block "{}"
> []
> ```
> ```
> $ runghc -itest test/Spec.hs --match "Step 5.2"
> 8 examples, 0 failures
> $ make part5
> 21 examples, 0 failures
> ```

---

## Part 6: loops
```
for i from 1 to 5 {
    square i * 10
}
```

### Step 6.1: `forLoop`
**Implement** `forLoop` from four pieces, in order:

1. `keyword "for"`, then a `name` (the loop variable);
2. `keyword "from"`, then an `expr`;
3. `keyword "to"`, then an `expr`;
4. a `block`.

Keep only the interesting results (`<-+>` drops each keyword). Sequencing the four pieces with `<+>` gives
**nested pairs**, `(((var, from), to), body)`. Take them apart with a lambda and build `For var from to body`.

> **✅ Check your work (Step 6.1)**
> <!-- state: 6.1 -->
> ```
> ghci> parseStmt "for i from 1 to 5 { square i * 10 }"
> For "i" (Num 1.0) (Num 5.0) [Square (Mul (Var "i") (Num 10.0))]
> ```
> ```
> $ runghc -itest test/Spec.hs --match "Step 6.1"
> 13 examples, 0 failures
> ```

### Step 6.2: nested loops
Nothing new: a loop's body is a block, a block holds statements, and a statement can be a loop.

> **✅ Check your work (Step 6.2, and all of Part 6)**
> <!-- state: 6.1 -->
> ```
> ghci> parseStmt "for i from 1 to 2 { for j from 1 to 3 { dot } }"
> For "i" (Num 1.0) (Num 2.0) [For "j" (Num 1.0) (Num 3.0) [Dot]]
> ```
> ```
> $ runghc -itest test/Spec.hs --match "Step 6.2"
> 2 examples, 0 failures
> $ make part6
> 15 examples, 0 failures
> ```

---

## Part 7: procedure calls
```
f()
box(20, 5)
foo(x + 1, y * 2)
```

### Step 7.1: `call`
**Implement** `call`: a `name`, then, **inside parentheses**, zero or more expressions **separated by commas**.
`sepBy` does exactly that (`sym ','` reads a comma). Build `Call name args` (`uncurry` again).

Calls and assignments both start with a name. `stmt` tries `assignment` first, and it fails when there's no `=`,
so then `call` gets its turn.

> **✅ Check your work (Step 7.1, and all of Part 7)**
> <!-- state: 7.1 -->
> ```
> ghci> parseStmt "f()"
> Call "f" []
> ghci> parseStmt "box(20, 5)"
> Call "box" [Num 20.0,Num 5.0]
> ghci> parseStmt "foo(x + 1, y * 2)"
> Call "foo" [Add (Var "x") (Num 1.0),Mul (Var "y") (Num 2.0)]
> ```
> ```
> $ runghc -itest test/Spec.hs --match "Step 7.1"
> 16 examples, 0 failures
> $ make part7
> 16 examples, 0 failures
> ```

---

## Part 8: procedure definitions
```
define box(size, gap) {
    square size
    move right size + gap
}
```

### Step 8.1: `procDef`
**Implement** `procDef`: `keyword "define"`, a `name`, a comma-separated list of parameter **names** in
parentheses, and a `block`. As with `forLoop`, sequencing gives nested pairs; build `ProcDef name params body`.

> **✅ Check your work (Step 8.1, and all of Part 8)**
> <!-- state: 8.1 -->
> ```
> ghci> parse procDef "define box(size, gap) { square size move right size + gap }"
> ProcDef "box" ["size","gap"] [Square (Var "size"),Move Rt (Add (Var "size") (Var "gap"))]
> ```
> ```
> $ runghc -itest test/Spec.hs --match "Step 8.1"
> 14 examples, 0 failures
> $ make part8
> 14 examples, 0 failures
> ```

---

## Part 9: whole programs
```
program ::= procdef* stmt*
```
**All definitions come first**, then the statements. A `define` after a statement is an error.

### Step 9.1: `program`
**Implement** `program`: any number of definitions, then the statements, built into a `Program` (`uncurry` once
more).

> **✅ Check your work (Step 9.1)**
> <!-- state: 9.1 -->
> ```
> ghci> parseProgram "define star() { dot } star() star()"
> Program [ProcDef "star" [] [Dot]] [Call "star" [],Call "star" []]
> ghci> parseProgram "dot define f() { }"
> *** Exception: <input>:1:11 -- No parse (via pfail)
> …
> ```
> ```
> $ runghc -itest test/Spec.hs --match "Step 9.1"
> 11 examples, 0 failures
> ```

### Step 9.2: program round trips
The final round trip: **every one of last week's 21 example programs** is printed as source code and parsed back,
and must come out identical. Parsing the printed program must also compile to exactly the same Python. And two
programs written the way a person would (fewer parentheses, different layout) must parse to exactly their ASTs.

> **✅ Check your work (Step 9.2, and all of Part 9)**
> <!-- state: 9.1 -->
> ```
> ghci> parseProgram (prettyProgram exampleProgram) == exampleProgram
> True
> ```
> ```
> $ runghc -itest test/Spec.hs --match "Step 9.2"
> 24 examples, 0 failures
> $ make part9
> 35 examples, 0 failures
> ```

---

## Part 10: the whole pipeline
Your parser is complete. Now piq is a language you can write in files.

### Step 10.1: from a file to a picture
Build the tools, then run a program through the whole pipeline: your parser, the provided compiler, the Python file,
and the mock plotter's picture.

> **✅ Check your work (Step 10.1)**
> <!-- state: 9.1 -->
> ```
> $ make
> …
> $ bin/piq2png programs/example.piq
> Writing programs/example.py
> Rendering programs/example.py to programs/example.png
> [nextdraw_backend] Using MOCK NextDraw (preview only)
> [mock_nextdraw] Saved preview to …/programs/example.png
> ```
> **Drawing check:** `programs/example.png` shows three targets, each three circles and a centre dot, growing from
> left to right, with a line underneath. Blue is drawn; the thin pink lines are pen-up travel (including the trip
> from the plotter's home corner at the top left). The grey dashed box is the safe area: see Step 10.3.
> ```
> $ runghc -itest test/Spec.hs --match "Step 10.1"
> 7 examples, 0 failures
> ```
> Also try `bin/piq2png programs/garden.piq` (flowers on a ground line, with a sun) and
> `bin/piq2png programs/woven.piq` (an abstract pattern: curves made only of straight lines).

### Step 10.2: errors stop the pipeline
An invalid program must never become a Python file. A syntax error stops at your parser; an error like an undefined
variable stops at the compiler.

> **✅ Check your work (Step 10.2, and all of Part 10)**
> <!-- state: 9.1 -->
> ```
> $ echo 'square 10 circle r' > programs/bad.piq
> $ bin/piq2py programs/bad.piq
> error: undefined variable: r
> ```
> No `programs/bad.py` is written. (Delete `programs/bad.piq` afterwards.)
> ```
> $ runghc -itest test/Spec.hs --match "Step 10.2"
> 5 examples, 0 failures
> $ make part10
> 12 examples, 0 failures
> ```

### Step 10.3: your own program
Write your own drawing in a new file, `programs/mine.piq`. Use `SYNTAX.md` for reference, and look at
`programs/garden.piq` for ideas. Then run `bin/piq2png programs/mine.piq`. Keep the drawing inside the **safe area**,
the grey dashed box in the preview: at least 1 inch from the paper's edges, which means within 190.5 mm left/right
and 114.3 mm up/down of the start. Anything outside it is drawn in red with a warning, and the real plotter refuses
to draw it.

### The final check
> **✅ Check your work (everything)**
> <!-- state: 9.1 -->
> ```
> $ make test
> 255 examples, 0 failures
> ```

---

## Common pitfalls
- **Alternatives without parentheses.** `p1 >>=: f <|> p2 >>=: g` groups wrongly; write `(p1 >>=: f) <|> (p2 >>=: g)`.
- **Using `text` for a keyword.** `text "move"` also matches the start of `movement`; use `keyword`.
- **Right associativity by accident.** If `10 - 3 - 2` gives `Sub (Num 10.0) (Sub …)`, `combineLeft` (or the way you
  combine) is grouping from the right.
- **Forgetting that the first operand isn't in the list.** In `a + b + c`, the list of pairs has two entries, not
  three.
- **Nested pairs.** `a <+> b <+> c` produces `((a, b), c)`, not `(a, b, c)`.
- **Tests that pass too early:** "is rejected" tests pass while a parser rejects everything. Check the step's full
  summary line after you finish the step.
- **Forgetting `:reload`** in GHCI after editing.
- **The `"` before `*** Exception`** is GHCI starting to print a string result. It's not part of the message.

---

## Final checklist
- [ ] `make test` shows `255 examples, 0 failures`.
- [ ] No placeholders are left in `PiqParser.hs`: `grep -nE 'error "TODO|pfail$' PiqParser.hs` prints nothing.
      (In the starter it finds 18.)
- [ ] `bin/piq2png programs/example.piq` produces the three targets.
- [ ] Your own `programs/mine.piq` draws what you intended.
- [ ] You didn't edit the provided files (including `ParserCombinators.hs`, `ParserBase.hs`, and `test/`).

## Submitting
Submit on Gradescope under **HW 06: PicPlot Part 2: Parsing**, following the "Turning It In" section of the course
page: <https://www.cs.hmc.edu/~bang/cs131/assignments/hw06/#turning-it-in>. In short: confirm you finished HW 5
before opening this repo, paste your `make test` output, upload `PiqParser.hs`, and upload `programs/mine.piq` with
`programs/mine.png`.

---

## Appendix: the real plotter
Drawing on the real NextDraw plotter happens **in the lab, with your instructor's setup and permission**. Follow
the course procedure:

- **Preview first.** Never send a drawing to the plotter that you haven't previewed (`bin/piq2png`) and checked.
- The plotter refuses any drawing that leaves the safe area (190.5 mm left/right and 114.3 mm up/down of the start).
- Before plotting, the carriage must be at its **home position** (the top-left corner).
- On the plotter computer, which has the NextDraw software installed, a generated program runs with `--doplot`:
  ```
  python programs/example.py --doplot
  ```
