# piq: concrete syntax

This is what piq source code looks like. It is exactly what your parser (`PiqParser.hs`) must read, and what the
provided pretty-printer (`PiqPretty.hs`) writes.
Sizes and distances are in millimetres. `up` is toward the top of the page.

## Example
```
define box(size, gap) {
    square size
    move right size + gap
}

x = 20
for i from 1 to 5 {
    box(i * 8, 10)
}
circle x / 2
line down 30
dot
```

## Grammar
```
program    ::= procdef* stmt*                        -- all definitions come first

procdef    ::= "define" name "(" names? ")" block
names      ::= name ("," name)*
block      ::= "{" stmt* "}"

stmt       ::= name "=" expr                         -- assignment
             | "dot"
             | "square" expr                         -- side length
             | "rectangle" expr expr                 -- width, then height
             | "circle" expr                         -- radius
             | "move" direction expr                 -- travel without drawing
             | "line" direction expr                 -- travel while drawing
             | "for" name "from" expr "to" expr block
             | name "(" exprs? ")"                   -- procedure call
exprs      ::= expr ("," expr)*
direction  ::= "left" | "right" | "up" | "down"

expr       ::= term (("+" | "-") term)*              -- left associative
term       ::= factor (("*" | "/") factor)*          -- left associative, binds tighter
factor     ::= number | name | "(" expr ")"
```

## Which parser handles which rule
| Grammar rule | Parser in `PiqParser.hs` | Part |
|---|---|---|
| names and reserved words | `name`, `keyword` | 1 |
| `factor` | `factor` | 2 |
| `expr`, `term`, operators | `expr`, `term`, `addOp`, `mulOp` (with `combineLeft`) | 3 |
| `direction`, and each `stmt` alternative except `for` and calls | `direction`, `dotStmt`, `squareStmt`, `rectangleStmt`, `circleStmt`, `moveStmt`, `lineStmt`, `assignment` | 4 |
| `stmt*`, `block` | `stmts`, `block` | 5 |
| `"for" …` | `forLoop` | 6 |
| `name "(" exprs? ")"` | `call` | 7 |
| `procdef` | `procDef` | 8 |
| `program` | `program` | 9 |

## Tokens
- **Whitespace:** spaces, tabs and newlines are all the same, and only separate tokens. There are no semicolons, and
  a whole program could be written on one line.
- **Names** (variables, procedures, parameters): a letter followed by letters and digits. This is the course
  library's `identifier`, so there are no underscores: `starGap` is fine, `star_gap` is not.
- **Reserved words:** these cannot be names.
  `dot square rectangle circle move line left right up down for from to define`
- **Numbers:** the course library's `double`: `20`, `2.5`, `-3`, `1.0e-2`. A leading `-` is part of the
  number. There is no minus operator for anything other than a number literal; write `0 - x` to negate a variable.
- **Case:** keywords are lowercase.

## Rules worth knowing
- **Distances are always required:** `move right 10`, never `move right`.
- **`rectangle W H` with a negative H** needs parentheses: `rectangle 30 (-10)`. Without them, `rectangle 30 -10`
  reads as `rectangle (30 - 10)` followed by a missing height.
- **Calls always have parentheses**, even with no arguments: `star()`.
- **Definitions come before statements**, but a procedure may call any procedure, including one defined later.
- **Recursion** (a procedure that calls itself, directly or indirectly) is not allowed. The compiler does not check for it.

## How the pretty-printer writes programs
- **Operations:** every one gets its own parentheses. `x + 5 * 2` prints as `(x + (5 * 2))`. This is valid input.
  It's just more parentheses than a person would write.
- **Whole numbers** print without `.0` (`20`, not `20.0`).
- **Negative numbers** print in parentheses: `move left (-45)`.
- **Indentation:** four spaces per block level. Each definition is followed by a blank line.
- **Not preserved:** blank lines and layout inside the program, and the choice of fewer parentheses. The AST does
  not record them.
