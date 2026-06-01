:- module(aspect,
          [ aspect_render/0,
            aspect_render/1,
            aspect_render/2
          ]).

% Modulo aspect: raccoglie i fatti aspect_* definiti dal programma utente,
% li traduce in comandi TikZ e compila il risultato in PDF con pdflatex.
% Riscrittura in Prolog del tool ASPECT, in origine scritto in Java.

:- use_module(library(process)).
:- use_module(library(filesex)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pairs)).
:- use_module(library(option)).

aspect_render :-
    aspect_render(aspect_output).

aspect_render(Output) :-
    aspect_render(Output, []).

aspect_render(Output, Options) :-
    collect_commands(Commands),
    ( Commands == []
    -> print_message(warning, format('ASPECT: no aspect_* facts found, nothing to draw', []))
    ;  true
    ),
    format(atom(TexFile), '~w.tex', [Output]),
    write_tex(TexFile, Commands),
    length(Commands, Len),
    format("ASPECT: wrote ~w (~d commands)~n", [TexFile, Len]),
    ( option(nobuild(true), Options)
    -> true
    ;  build_pdf(Output, TexFile)
    ).

% Quanti argomenti fissi ha ogni forma, prima di [attributi] e [frame] opzionali.
shape(drawnode,  3).
shape(imagenode, 3).
shape(line,      4).
shape(arrow,     4).
shape(rectangle, 4).
shape(arc,       5).
shape(triangle,  6).
shape(circle,    3).
shape(ellipse,   4).

collect_commands(Tikzs) :-
    findall(Layer-Tikz, gen_command(Layer, Tikz), Pairs),
    keysort(Pairs, Sorted),          % stabile: ordina per layer mantenendo l'ordine di disegno
    pairs_values(Sorted, Tikzs).

gen_command(Layer, Tikz) :-
    shape(Name, Fixed),
    atom_concat(aspect_, Name, AspectName),
    between(0, 2, Extra),            % attributi e frame sono opzionali
    Arity is Fixed + Extra,
    functor(Head, AspectName, Arity),
    current_predicate(_, user:Head), % salto le arietà non definite dall'utente
    call(user:Head),
    Head =.. [_|Args],
    length(FixedArgs, Fixed),
    append(FixedArgs, Optional, Args),
    split_optional(Optional, Attrs, _Frame),
    render(Name, FixedArgs, Attrs, Tikz, Layer).

% Un intero da solo è il frame, altrimenti sono gli attributi.
split_optional([],     no_attrs, no_frame).
split_optional([A],    Attrs, Frame) :-
    ( integer(A) -> Attrs = no_attrs, Frame = A
    ; Attrs = A, Frame = no_frame ).
split_optional([A, F], A, F).

render(rectangle, [X1,Y1,X2,Y2], Attrs, Tikz, Layer) :-
    resolve_attrs(Attrs, AttrStr, _, Layer),
    format(atom(Body), '(~w,~w) rectangle (~w,~w)', [X1,Y1,X2,Y2]),
    draw(AttrStr, Body, Tikz).
render(line, [X1,Y1,X2,Y2], Attrs, Tikz, Layer) :-
    resolve_attrs(Attrs, AttrStr, _, Layer),
    format(atom(Body), '(~w,~w) -- (~w,~w)', [X1,Y1,X2,Y2]),
    draw(AttrStr, Body, Tikz).
render(arrow, [X1,Y1,X2,Y2], Attrs, Tikz, Layer) :-
    resolve_attrs(Attrs, AttrStr0, _, Layer),
    ( AttrStr0 == '' -> AttrStr = '->' ; format(atom(AttrStr), '->,~w', [AttrStr0]) ),
    format(atom(Body), '(~w,~w) -- (~w,~w)', [X1,Y1,X2,Y2]),
    format(atom(Tikz), '\\draw [~w] ~w;', [AttrStr, Body]).
render(triangle, [X1,Y1,X2,Y2,X3,Y3], Attrs, Tikz, Layer) :-
    resolve_attrs(Attrs, AttrStr, _, Layer),
    format(atom(Body), '(~w,~w) -- (~w,~w) -- (~w,~w) -- cycle', [X1,Y1,X2,Y2,X3,Y3]),
    draw(AttrStr, Body, Tikz).
render(circle, [X,Y,R], Attrs, Tikz, Layer) :-
    resolve_attrs(Attrs, AttrStr, _, Layer),
    format(atom(Body), '(~w,~w) circle (~w)', [X,Y,R]),
    draw(AttrStr, Body, Tikz).
render(ellipse, [X,Y,R1,R2], Attrs, Tikz, Layer) :-
    resolve_attrs(Attrs, AttrStr, _, Layer),
    format(atom(Body), '(~w,~w) ellipse (~w and ~w)', [X,Y,R1,R2]),
    draw(AttrStr, Body, Tikz).
render(arc, [X,Y,A1,A2,R], Attrs, Tikz, Layer) :-
    resolve_attrs(Attrs, AttrStr, _, Layer),
    format(atom(Body), '(~w,~w) ++(~w:~w) arc (~w:~w:~w)', [X,Y,A1,R,A1,A2,R]),
    draw(AttrStr, Body, Tikz).
render(drawnode, [X,Y,Text], Attrs, Tikz, Layer) :-
    resolve_attrs(Attrs, AttrStr, _, Layer),
    node(AttrStr, X, Y, Text, Tikz).
render(imagenode, [X,Y,Img], Attrs, Tikz, Layer) :-
    resolve_attrs(Attrs, AttrStr, Width, Layer),
    image_content(Img, Width, Content),
    node(AttrStr, X, Y, Content, Tikz).

draw('', Body, Tikz) :- !,
    format(atom(Tikz), '\\draw ~w;', [Body]).
draw(AttrStr, Body, Tikz) :-
    format(atom(Tikz), '\\draw [~w] ~w;', [AttrStr, Body]).

node('', X, Y, Content, Tikz) :- !,
    format(atom(Tikz), '\\node at (~w,~w) {~w};', [X, Y, Content]).
node(AttrStr, X, Y, Content, Tikz) :-
    format(atom(Tikz), '\\node [~w] at (~w,~w) {~w};', [AttrStr, X, Y, Content]).

image_content(Img, no_width, Content) :- !,
    format(atom(Content), '\\includegraphics{~w}', [Img]).
image_content(Img, Width, Content) :-
    format(atom(Content), '\\includegraphics[width=~wpt]{~w}', [Width, Img]).

% Dai nomi di stile ricavo le opzioni TikZ, la larghezza e il layer.
% width non è un'opzione TikZ (serve per le immagini), quindi la estraggo a parte.
resolve_attrs(no_attrs, '', no_width, 0) :- !.
resolve_attrs(Attrs, AttrStr, Width, Layer) :-
    style_names(Attrs, Names),
    findall(KA-V, ( member(N, Names), style_fact(N, K, V), to_atom(K, KA) ), Pairs0),
    ( select(width-Width, Pairs0, Pairs) -> true ; Width = no_width, Pairs = Pairs0 ),
    pairs_to_attr(Pairs, AttrStr),
    layer_of(Names, Layer).

style_names(List, List) :- is_list(List), !.
style_names(Atom, [Atom]).

pairs_to_attr(Pairs, AttrStr) :-
    findall(S, ( member(K-V, Pairs), attr_kv(K, V, S) ), Parts),
    atomic_list_concat(Parts, ',', AttrStr).

attr_kv(K, V, S) :-
    ( V == '' ; V == "" ), !,
    to_atom(K, S).
attr_kv(K, V, S) :-
    format(atom(S), '~w=~w', [K, V]).

layer_of(Names, Layer) :-
    ( member(N, Names), layer_fact(N, L) -> Layer = L ; Layer = 0 ).

% Se l'utente non ha definito stili o layer, fallisco invece di dare errore.
style_fact(N, K, V) :-
    current_predicate(_, user:aspect_style(_,_,_)),
    user:aspect_style(N, K, V).
layer_fact(N, L) :-
    current_predicate(_, user:aspect_layer(_,_)),
    user:aspect_layer(N, L).

to_atom(X, X)  :- atom(X), !.
to_atom(X, A)  :- format(atom(A), '~w', [X]).

write_tex(TexFile, Commands) :-
    setup_call_cleanup(
        open(TexFile, write, S),
        ( format(S, '\\documentclass[tikz, dvipsnames]{standalone}~n', []),
          format(S, '\\usepackage{xcolor}~n', []),
          format(S, '\\usetikzlibrary{calc}~n', []),
          format(S, '\\begin{document}~n', []),
          format(S, '\\begin{tikzpicture}~n', []),
          forall(member(C, Commands), format(S, '  ~w~n', [C])),
          format(S, '\\end{tikzpicture}~n', []),
          format(S, '\\end{document}~n', [])
        ),
        close(S)).

build_pdf(Output, TexFile) :-
    aux_dir(Output, Aux),
    ( exists_directory(Aux) -> true ; make_directory(Aux) ),
    format(atom(OutDirArg), '-output-directory=~w', [Aux]),
    process_create(path(pdflatex),
                   ['-interaction=nonstopmode', '-halt-on-error', OutDirArg, TexFile],
                   [ stdout(pipe(Out)), stderr(pipe(Err)), process(PID) ]),
    read_string(Out, _, Transcript),
    read_string(Err, _, _),
    close(Out), close(Err),
    process_wait(PID, Status),
    ( Status == exit(0)
    -> format(atom(PdfSrc), '~w/~w.pdf', [Aux, Output]),
       format(atom(PdfDst), '~w.pdf', [Output]),
       copy_file(PdfSrc, PdfDst),
       format("ASPECT: created ~w.pdf~n", [Output])
    ;  format("ASPECT ERROR: pdflatex failed (~w). Transcript follows:~n~w~n",
              [Status, Transcript]),
       fail
    ).

aux_dir(Output, Aux) :-
    format(atom(Rel), '~w_aux', [Output]),
    absolute_file_name(Rel, Aux).
