defmodule Edata.Datalog.Rumore do
  defstruct map: %{}, allow_duppar: true
  alias __MODULE__, as: R
  alias Edata.Datalog.Facts, as: F
  alias Edata.Datalog.Misc, as: M

  def new(), do: %R{}
  def new(m), do: %R{map: m}

  def disallow_duppar(%R{allow_duppar: false} = r), do: r
  def disallow_duppar(%R{} = r), do: %R{r | allow_duppar: false}

  def add(%R{ map: m }, rdesc) do
    {call, args, body} = M.parse_rule(rdesc)
    nm = Map.update(m, {call, length(args)}, [{args, body}], fn lst -> lst ++ [{args, body}] end) # [{args, body} | lst]
    new(nm)
  end

  def rulesfor(%R{ map: m }, pred), do: Map.get(m, pred, [])

  # def rulesfor(%R{} = rls, call, args) do
  #   rulesfor(rls, {call, length(args)})
  #   |> Stream.reject(fn {params, _body} ->
  #     params |> Stream.zip(args)
  #     |> Enum.any?(
  #       fn {p, a} when not is_atom(p) and not is_atom(a) -> p != a
  #           _ -> false
  #       end)
  #   end)
  # end

  def pre_bound(%R{} = rls, call, args) do
   rulesfor(rls, {call, length(args)})
    |> Stream.map(fn {params, body} -> {params |> Enum.filter(&(is_atom(&1))), body,
      params |> Stream.zip(args)
      |> Enum.reduce_while(%{},
      fn  {p, a}, m when not is_atom(p) and not is_atom(a) ->
            if p != a, do: {:halt, nil}, else: {:cont, m}
          {p, a}, m -> {:cont, Map.put(m, a, p) }
      end)
      }
    end)
    |> Stream.filter(fn {_params, _body, m} -> m != nil end)
  end

  def pre_bound2(%R{allow_duppar: adp} = rls, call, args) do
    case adp do
      true ->
        rulesfor(rls, {call, length(args)})
        |> Stream.map(fn {params, body} -> {body, lbind_c(params, args)} end)
      _ ->
        rulesfor(rls, {call, length(args)})
        |> Stream.map(fn {params, body} -> {body, lbind_cd(params, args)} end)
    end
    |> Stream.filter(fn {_body, m} -> m != nil end)
  end

  def lbind_c(l1, l2), do: lbind_c(l1, l2, %{}, %{})
  def lbind_c([], _l2, out, mapping), do: {out, mapping}
  def lbind_c([p | pt], [a | at], out, mapping) do
    case is_atom(p) do
      true ->
        case Map.get(mapping, p) do
          nil -> lbind_c(pt, at, out, Map.put(mapping, p, a)) # fresh
          ^a -> lbind_c(pt, at, out, mapping)           # bound already
          diff -> lbind_c(pt, at, Map.put(out, a, diff), mapping)
        end
      _ ->
        case is_atom(a) do
          true -> lbind_c(pt, at, Map.put(out, a, p), mapping)
          _ -> if p != a, do: nil, else: lbind_c(pt, at, out, mapping)
        end
    end
  end

  def lbind_cd(l1, l2), do: lbind_cd(l1, l2, %{}, %{})
  def lbind_cd([], _l2, out, mapping), do: {out, mapping}
  def lbind_cd([p | pt], [a | at], out, mapping) do
    case is_atom(p) do
      true ->
        lbind_cd(pt, at, out, Map.put(mapping, p, a))
      _ ->
        case is_atom(a) do
          true -> lbind_cd(pt, at, Map.put(out, a, p), mapping)
          _ -> if p != a, do: nil, else: lbind_cd(pt, at, out, mapping)
        end
    end
  end

  def join_stream(lhs, rhs), do: M.stream_cross_wi(lhs, rhs, &M.mmerge/2) |> Stream.filter(&(&1 != nil))

  def ask_pure(%R{allow_duppar: adp} = rules, %F{} = facts, {pred, _context, arglist}, logger \\nil) do
    r = ask_pure(rules, facts, pred, M.exarglist(arglist), 0, logger)
    if adp, do: r |> Stream.map(&M.resolve_innerref(&1)), else: r
  end

  def ask_pure(%R{} = rules, %F{} = facts, pred, args, l, logger \\ nil) do
    factstream = F.resolve_stream(facts, pred, args) #F.bind_stream(args, F.factsfor(facts, pred))
    rulestream = R.bind_stream(pre_bound2(rules, pred, args), rules, facts, l+1, logger)
    #|> Stream.filter(&(&1 != nil))
    Stream.concat(factstream, rulestream)
  end

  def bind_stream(cands, rules, facts, l, logger) do
    Stream.flat_map(cands,
    fn {{:stream, str}, {preknown, mapping}} -> resolve_str(str, preknown, mapping)
      {_body, {_preknown, _mapping}} = call ->
      #IO.inspect(call)
      resolve_pure(call, rules, facts, l, logger)
    end) #|> Stream.filter(&(&1 != nil))
  end

  def resolve_str(str, preknown, mapping) when map_size(preknown) == 0 and map_size(mapping) == 1 do
    case mapping |> Enum.take(1) do
      [{_k, v}] when is_atom(v) ->
        str |> Stream.map(fn e -> %{v => e} end)
      [{_k, v}] ->
        str |> Stream.filter(fn e -> e == v end) |> Stream.map(fn _e -> %{} end)
    end
  end

  def resolve_pure(_, _, _, 18, _) do
    IO.puts("pure Terminated"); []
  end
  def resolve_pure({body, {preknown, mapping}}, rules, facts, level, logger) do
    #IO.puts(inspect(level))
    # mapping = M.mapargs(ral, args)
    # IO.inspect(preknown)
    body |> Stream.map(fn
        {mod, call, cpars} ->
          case mod do
            :not -> handle_pure(call, cpars, mapping, rules, facts, level, &negate_wrapper/1, logger)
            :any -> handle_pure(call, cpars, mapping, rules, facts, level, &any_wrapper/1, logger)
          end
        {call, cpars} -> handle_pure(call, cpars, mapping, rules, facts, level, &default_wrapper/1, logger)
    end)
    |> Enum.reduce_while([preknown], fn r, acc -> #
      case M.empty?(r.(acc)) do
        {true, _} -> {:halt, []}
        {false, localresult} -> joinr = join_stream(acc, localresult) # |> Enum.to_list
            case M.empty?(joinr) do
              {true, _}  -> {:halt, []}
              {false, s}   -> {:cont, s}
            end
      end
    end)
  end

  # defp default_wrapper, do: &(&1)
  # defp negate_wrapper do
  #   fn x ->
  #     case M.empty?( x ) do
  #       {true, _s} -> [%{}]
  #       _ ->  []
  #     end
  #   end
  # end
  # defp any_wrapper do
  #   fn x -> x |> Enum.take(1)
  #   end
  # end

  defp default_wrapper(map) when map_size(map) == 0, do: &(&1)
  defp default_wrapper(map), do: &(&1 |> inject_keys_pure(map))
  defp negate_wrapper(map) do
    fn x ->
      case M.empty?( x ) do
        {true, _s} -> [map]
        _ ->  []
      end
    end
  end

  defp any_wrapper(map) when map_size(map) == 0 do
    fn x -> x |> Enum.take(1)
    end
  end
  defp any_wrapper(map) do
    fn x ->
      case (x |> Enum.take(1)) do
        [] -> []
        [m] -> [ m |> Map.merge(map) ]
      end
    end
  end

  def handle_pure(call, cpars, mapping, rules, facts, level, wr, logger \\ nil) do
    #wrapper = wr.()
    lcargs = M.maplocal(mapping, cpars, level)
    #IO.inspect({:pure, call, cpars, mapping, level, lcargs})
    fn currentset ->
      potsub =
      currentset
      |> Stream.map(fn m -> {m, lcargs |> Enum.map(fn l -> Map.get(m, l, l) end)}  end)
     # IO.puts(inspect([cs: currentset, cpars: cpars, potsub: potsub]))
      potsub
      |> Stream.flat_map(fn {m, ps} ->
        #logger && send logger, {call, ps, 0}# IO.inspect([:calling, call, m, ps]) # erlang:system_time(:microsecond)
            wr.(m).(ask_pure(rules, facts, call, ps, level, logger))
            #|> inject_keys_pure(m)
          end)
    end # fn currentset
  end

  # def timeit(fun, nil, _call, _ps) when is_function(fun,0), do: fun.()
  # def timeit(fun, logger, call, ps) when is_function(fun,0) do
  #   {_,bes, bem} = :erlang.now() #:erlang.system_time(:microsecond)
  #   r = fun.()
  #   {_,afs, afm} = :erlang.now()

  #   total = (1_000_000 * afs + afm) - (1_000_000 * bes + bem)

  #   send logger, {call, ps, total}
  #   r
  # end

  def inject_keys_pure(str, m) do
    str |> Stream.map(fn e -> Map.merge(e, m) end)
  end

  def mrs() do
    R.new()
|> R.add(quote do dec(A, B) -> inc(B, A) end)
|> R.add(quote do nonzero(X) -> int(X); not zero(X) end)

|> R.add(quote do add(A, B, R) -> zero(A); zero(B); zero(R) end)
|> R.add(quote do add(A, B, R) -> zero(A); nonzero(B); int(R); eq(B, R) end)
|> R.add(quote do add(A, B, R) -> zero(B); nonzero(A); int(R); eq(A, R) end)
|> R.add(quote do add(A, B, R) -> nonzero(B); dec(A, AD); inc(B, BI); any add(AD, BI, R) end) # nonzero(A);

|> R.add(quote do greater(A, B) -> zero(B); nonzero(A) end)
|> R.add(quote do greater(A, B) -> nonzero(A); nonzero(B); not eq(A, B); dec(A, AD); dec(B, BD); greater(AD, BD) end)

|> R.add(quote do less(A, B) -> greater(B, A) end)

|> R.add(quote do delta(A, B, D) -> int(A); int(B); eq(A, B); zero(D) end)
|> R.add(quote do delta(A, B, D) -> greater(A, B); add(B, D, A) end)
|> R.add(quote do delta(A, B, D) -> greater(B, A); add(A, D, B) end)

|> R.add(quote do sub(A, B, R) -> add(B, R, A) end)

|> R.add(quote do mult(A, B, R) -> zero(A); int(B); zero(R) end)
|> R.add(quote do mult(A, B, R) -> one(A); int(B); int(R); eq(B, R) end)
|> R.add(quote do mult(A, B, R) -> zero(B); greater_one(A); zero(R) end)
|> R.add(quote do mult(A, B, R) ->
  # greater_one(A); nonzero(B);
  # dec(A, AD); any mult(AD, B, RR); any add(B, RR, R)
  dec(A, AD); not zero(AD); nonzero(B);
  any mult(AD, B, RR); any add(B, RR, R)
end)

|> R.add(quote do greater_one(X) -> int(X); not zero(X); not one(X) end)

|> R.add(quote do div(A, B, R) -> nonzero(B); mult(B, R, A) end)
  end

  def ints() do
    F.new()
|> F.add(quote do int(0); int(1); int(2); int(3); int(4); int(5); int(6); int(7); int(8); int(9); int(10) end)  #; ; int(5); int(6); int(7); int(8); int(9)
|> F.add(quote do inc(0, 1); inc(1, 2); inc(2, 3); inc(3, 4); inc(4, 5); inc(5, 6); inc(6, 7); inc(7, 8); inc(8,9); inc(9, 10) end) # ; inc(4, 5); inc(5, 6); inc(6, 7); inc(7, 8); inc(8,9)
|> F.add(quote do zero(0); one(1) end)
  end

  # def dj(given_args) do
  #   rule_params = [X, Y]
  #   mapping = M.mapargs(rule_params, given_args)
  #   facts = F.new() |> F.add(quote do edge(a, b); edge(b, c) end)

  #   {true, lhs} = F.askf(facts, quote do edge(X, M) end)
  #   {true, rhs} = F.askf(facts, quote do edge(M, Y) end)

  #   r = ( for l <- lhs, r <-rhs, do: Misc.mmerge(l, r, [:M]) ) |> Enum.filter(&(&1 != nil))
  # end

  #def askr(%R{ map: _m } = rules, {pred, _context, arglist}) do
  #  al = M.exarglist(arglist)
  #  relrules = rulesfor(rules, pred)
  #end
# quote do related(A, B) -> parent(A, B) end
# => [
#  {:->, [],
#  [
#    [
#      {:related, [],
#       [
#         {:__aliases__, [alias: false], [:A]},
#         {:__aliases__, [alias: false], [:B]}
#       ]}
#    ],
#    {:parent, [],
#     [
#       {:__aliases__, [alias: false], [:A]},
#       {:__aliases__, [alias: false], [:B]}
#     ]}
#  ]}
#]

# quote do related(A, B) -> parent(A, B); foo(B) end
# => [
#  {:->, [],
#  [
#    [
#      {:related, [],
#       [
#         {:__aliases__, [alias: false], [:A]},
#         {:__aliases__, [alias: false], [:B]}
#       ]}
#    ],
#    {:__block__, [],
#     [
#       {:parent, [],
#        [
#          {:__aliases__, [alias: false], [:A]},
#          {:__aliases__, [alias: false], [:B]}
#        ]},
#       {:foo, [], [{:__aliases__, [alias: false], [:B]}]}
#     ]}
#  ]}
#]
end #module
