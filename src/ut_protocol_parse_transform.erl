-module (ut_protocol_parse_transform).
-export ([parse_transform/2]).

-define (F, coders).

parse_transform (Forms, _Options) ->
  lists:flatten ([form (Form) || Form <- Forms]).

form ({function, _Line, ?F, Arity, Clauses})
when Arity =:= 0 andalso length (Clauses) =:= 1 ->
  lists:flatten (coders (hd (Clauses)));

form ({function, Line, ?F, _Arity, _Clauses}) ->
  {error, {Line, erl_parse, ["expected arity of 0 and a single clause"]}};

form (F) -> F.

coders ({clause, Line, Head, Guard, Exprs})
when Head =:= [] andalso Guard =:= [] ->
  {Encoders, Decoders, Errors} = lists:foldl (fun (Expr, {AEn, ADe, AEr}) ->
      case expr (Expr) of
        {error, E} ->
          {AEn, ADe, AEr ++ [{error, E}]};
        Coders ->
          Es = lists:map (fun ({coders, E, _}) -> E end, Coders),
          Ds = lists:map (fun ({coders, _, D}) -> D end, Coders),

          {AEn ++ Es, ADe ++ Ds, AEr} end end,
    {[], [], []}, Exprs),

  [Errors,
   {function, Line, encode, 1, Encoders},
   {function, Line, decode, 1, Decoders}];

coders ({clause, Line, _Head, _Guard, _Exprs}) ->
  {error, {Line, erl_parse, ["expected no head and no guards"]}}.

expr ({tuple, Line, [Record, Bin]}) ->
  expr ({tuple, Line, [Record, Bin, {nil, Line}, {nil, Line}]});

expr ({tuple, Line, [Record, Bin, Fills]}) ->
  expr ({tuple, Line, [Record, Bin, Fills, {nil, Line}]});

expr ({tuple, Line, [{record, RLine, RName, RFields},
                     {bin, BLine, BElems},
                     Fills, Transforms]}) ->
  Fills_ = case lists:map (fun ast_to_list/1,  ast_to_list (Fills)) of
    [] -> [[]];  % Do a single pass instead of zero passes.
    L  -> L end,
  Transforms_ = lists:map (fun ast_to_tuple/1, ast_to_list (Transforms)),

  lists:map (fun (Fill) ->
      RFields_ = lists:flatten (fill (RLine, RFields, Fill)),
      BElems_  = lists:flatten (fill (BLine, BElems,  Fill)),

      Rec = {record, RLine, RName, RFields_},
      Bin = {bin, BLine, BElems_},

      E = build_clause (encoder, Line, Rec, Bin, Transforms_),
      D = build_clause (decoder, Line, Rec, Bin, Transforms_),
      {coders, E, D} end,
    Fills_);

expr (Expr) ->
  Line = element (2, Expr),
  {error, {Line, erl_parse, ["unexpected expression"]}}.

fill (_Line, Exprs, Fill) ->
  lists:map (fun (Expr) -> fill_child (Expr, Fill) end, Exprs).

fill_child ({record_field, Line, Name, Value}, Fill) ->
  {record_field, Line, Name, fill_child (Value, Fill)};

fill_child ({bin_element, Line, Value, Size, TypeSpecs}, Fill) ->
  Action = case Value of
    {atom, ALine, AName} ->
      case {atom_to_list (AName), Size, TypeSpecs} of
        {"$+" ++ Num, default, default} ->
          {substitute_bin_elements, ALine, list_to_integer (Num)};
        {"$+" ++ Num, _, _} ->
          {error, {ALine, erl_parse,
                   ["no size or type specifiers expected with $+", Num]}};
        {_, _, _} ->
          default end;
    {_, _, _} ->
      default end,

  case Action of
    {error, E} ->
      {error, E};
    {substitute_bin_elements, L, N} ->
      substitute_bin_elements (L, N, Fill);
    default ->
      {bin_element, Line,
       fill_child (Value, Fill), fill_child (Size, Fill),
       TypeSpecs} end;

fill_child ({atom, Line, Name}, Fill) ->
  case atom_to_list (Name) of
    "$" ++ Num ->
      lists:nth (list_to_integer (Num) + 1, Fill);
    _ ->
      {atom, Line, Name} end;

fill_child (Expr, _Fill) -> Expr.

substitute_bin_elements (Line, N, Fill) ->
  FillItem = lists:nth (N+1, Fill),

  case FillItem of
    {bin, _BLine, BElems} ->
      BElems;
    _ ->
      {error, {Line, erl_parse, ["$+N refers to a non-bin element"]}} end.

build_clause (Mode, Line, Rec, Bin, Transforms) ->
  Exprs = lists:map (fun ({{atom,_,Name}, Enc, Dec}) ->
      NameT = list_to_atom (atom_to_list (Name) ++ "T"),

      {F, In, Out} = case Mode of
        encoder -> {Enc, Name, NameT};
        decoder -> {Dec, NameT, Name} end,

      {match, Line,
       {var, Line, Out},
       {call, Line, F, [{var, Line, In}]}} end,
    Transforms),

  {Head, FinalExpr} = case Mode of
    encoder -> {Rec, Bin};
    decoder -> {Bin, Rec} end,

  {clause, Line, [Head], [], Exprs ++ [FinalExpr]}.

ast_to_list ({nil, _Line})              -> [];
ast_to_list ({cons, _Line, Head, nil})  -> [Head];
ast_to_list ({cons, _Line, Head, Tail}) -> [Head | ast_to_list (Tail)].

ast_to_tuple ({tuple, _Line, Exprs}) ->
  lists:foldl (fun (Expr, Acc) ->
      erlang:append_element (Acc, Expr) end,
    {}, Exprs).

% vim:set et sw=2 sts=2:
