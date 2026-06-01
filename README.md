# ASPECT for SWI-Prolog

A self-contained SWI-Prolog pack that turns `aspect_*` facts into TikZ/LaTeX
vector graphics and compiles them to **PDF**, directly from within Prolog.

It is a Prolog re-implementation of the [ASPECT](https://github.com/abertagnon/aspect)
tool (originally a Java CLI by Alessandro Bertagnon): instead of piping an ASP
solver's output through an external program, your Prolog program defines the
drawing as ordinary predicates and one call renders it.

## Requirements

- **SWI-Prolog** ≥ 9.0
- A **LaTeX** engine: `pdflatex` (e.g. [MiKTeX](https://miktex.org/) or TeX Live).
  TikZ/`standalone`/`xcolor` packages are pulled in automatically by MiKTeX on
  first use.

## Quick start

Define the picture as `aspect_*` predicates, then render. The pattern is
**solve, assert the solution as facts, draw from those facts**:

```prolog
:- use_module(library(aspect)).
:- dynamic queen/2.

solve :- once(solve_queens(Qs)), forall(nth1(I,Qs,J), assertz(queen(I,J))).

aspect_rectangle(X1,Y1,X2,Y2, dark)  :- /* … light/dark squares … */ .
aspect_imagenode(X, Y, "queen.png", queen) :- queen(I,J), X is 2*I, Y is 2*J.

aspect_style(dark,  fill,  gray).
aspect_style(queen, width, 50).
aspect_layer(dark,  0).
aspect_layer(queen, 1).      % higher layer → drawn on top

main :- solve, aspect_render(queens).   % → queens.tex + queens.pdf
```

Run the bundled example:

```bash
cd examples
swipl queens.pl
?- main.
```

This writes `queens.tex` and `queens.pdf` (an 8×8 board with a valid 8-queens
placement) into the current directory.

## API

| Predicate | Description |
|-----------|-------------|
| `aspect_render` | Render to `aspect_output.tex` / `.pdf`. |
| `aspect_render(+Output)` | Render to `<Output>.tex` / `<Output>.pdf`. |
| `aspect_render(+Output, +Options)` | Options: `nobuild(true)` emits only the `.tex`. |

## Supported atoms (v0.1)

Drawing: `aspect_drawnode/3`, `aspect_imagenode/3`, `aspect_line/4`,
`aspect_arc/5`, `aspect_arrow/4`, `aspect_rectangle/4`, `aspect_triangle/6`,
`aspect_circle/3`, `aspect_ellipse/4`. Each takes an optional trailing
**attributes** argument (a style name or a **list** of style names).

Directives: `aspect_style(Name, Key, Value)`, `aspect_layer(Name, Index)`.

Beamer/animate/free modes, graph mode, labels, `dl/2`, and image export are
planned for future versions.

## License

See the upstream ASPECT project. This is an academic port.
