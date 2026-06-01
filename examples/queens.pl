% N-regine disegnate con library(aspect), in stile "option A" (soluzione asserita).
% Eseguire da questa cartella examples/, così queen.png e l'output finiscono qui:
%   swipl queens.pl
%   ?- main.

:- use_module('../prolog/aspect').
:- use_module(library(clpfd)).

:- dynamic queen/2.

n(8).

solve_queens(Queens) :-
    n(N),
    length(Queens, N),
    Queens ins 1..N,
    all_distinct(Queens),
    safe_diagonals(Queens),
    labeling([], Queens).

safe_diagonals(Queens) :- safe_diagonals(Queens, 1).
safe_diagonals([], _).
safe_diagonals([Q|Qs], I) :-
    safe_with(Q, Qs, I, 1),
    I1 is I + 1,
    safe_diagonals(Qs, I1).

safe_with(_, [], _, _).
safe_with(Q, [Q1|Qs], I, D) :-
    Q #\= Q1,
    abs(Q - Q1) #\= D,
    D1 is D + 1,
    safe_with(Q, Qs, I, D1).

% Risolvo una volta e salvo la soluzione come fatti queen/2.
solve :-
    retractall(queen(_, _)),
    once(solve_queens(Qs)),
    forall(nth1(I, Qs, J), assertz(queen(I, J))).

% I predicati aspect leggono i fatti queen/2, senza argomento-soluzione.
aspect_rectangle(X1, Y1, X2, Y2, dark) :-
    n(N), between(1, N, I), between(1, N, J),
    I mod 2 =:= J mod 2,
    X1 is 2*I - 1, Y1 is 2*J - 1, X2 is 2*I + 1, Y2 is 2*J + 1.
aspect_rectangle(X1, Y1, X2, Y2, light) :-
    n(N), between(1, N, I), between(1, N, J),
    I mod 2 =\= J mod 2,
    X1 is 2*I - 1, Y1 is 2*J - 1, X2 is 2*I + 1, Y2 is 2*J + 1.

aspect_imagenode(X, Y, "queen.png", queen) :-
    queen(I, J),
    X is 2*I, Y is 2*J.

aspect_style(dark,  fill,  gray).
aspect_style(light, fill,  white).
aspect_style(queen, width, 50).

aspect_layer(dark,  0).
aspect_layer(light, 0).
aspect_layer(queen, 1).

main :- solve, aspect_render(queens).
