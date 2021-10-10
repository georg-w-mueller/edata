defmodule Edata.Datalog.Rules do
  defstruct map: %{}
  alias __MODULE__, as: R
  alias Edata.Datalog.Facts, as: F
  alias Edata.Datalog.Misc, as: M

  def new(), do: %R{}
  def new(m), do: %R{map: m}

  def add(%R{ map: m }, rdesc) do
    {pred, args, body} = M.parse_rule(rdesc)
    nm = Map.update(m, pred, [{args, body}], fn lst -> [{args, body} | lst] end)
    new(nm)
  end

  def rulesfor(%R{ map: m }, pred), do: Map.get(m, pred, [])

  def ask_using(%R{} = rules, %F{} = facts, {pred, _context, arglist}) do
    resolveX(pred, M.exarglist(arglist), rules, facts)
    |> M.distinct_r()
  end

  def default, do: {false, []}
  def comb({_, _} = acc, {false, _}), do: acc
  def comb({_, l}, {true, al}), do: {true, l ++ al}

  def comb_not({_, l}, {false, al}), do: {true, l ++ al}
  def comb_not({_, _} = acc, {true, _}), do: acc

  def resolve(pred, args, %R{} = rules, %F{} = facts, level \\ 0) when is_atom(pred) and is_list(args) do
    #IO.puts(inspect({:call, pred, args, level }))
    lr = Enum.reduce(rulesfor(rules, pred), default(),
    fn  r, acc when is_tuple(r) -> rrr = resolve_(r, rules, facts, args, level + 1); #IO.puts(inspect({:rule, rrr}));
          comb(acc, rrr)
    end) |> comb(F.resolve(facts, pred, args))
    #IO.puts(inspect({:result, pred, args, level, lr })); lr
  end

  def resolve_(_, _, _, _, 16) do
    IO.puts("Terminated"); {false, []}
  end
  def resolve_({ral, body}, rules, facts, args, level) do
    #IO.puts(inspect(level))
    mapping = M.mapargs(ral, args)
    #IO.puts(inspect(mapping))

    body |> Stream.map(fn {call, cpars} ->
      #IO.puts(inspect([args, cpars]))
      lcargs = M.maplocal(mapping, cpars, level)
      resolve(call, lcargs, rules, facts, level)
    end)
    |> Enum.reduce_while([%{}], fn r, acc ->
      case r do
        {false, _} -> {:halt, :localfail}
        {true, localresult} -> joinr = join(acc, localresult)
            case joinr do
              []  -> {:halt, :joinfail}
              _   -> {:cont, joinr}
            end
      end
    end)
    |> case do
      r when is_list(r) -> {true, r}
      _ -> {false, []}
    end
  end

  def resolveX(pred, args, %R{} = rules, %F{} = facts, level \\ 0) when is_atom(pred) and is_list(args) do
    #IO.puts(inspect({:call, pred, args, level }))
    lr = F.resolve(facts, pred, args)
    |> comb(
      Enum.reduce(rulesfor(rules, pred), default(),
      fn  r, acc when is_tuple(r) -> rrr = resolve_X(r, rules, facts, args, level + 1);
            comb(acc, rrr)
      end) )
    #|> M.distinct_r()
    #IO.puts(inspect({:result, pred, args, level, lr })); lr
  end

  def resolve_X(_, _, _, _, 16) do
    IO.puts("X-Terminated"); {false, []}
  end
  def resolve_X({ral, body}, rules, facts, args, level) do
    #IO.puts(inspect(level))
    mapping = M.mapargs(ral, args)
    #IO.puts(inspect(mapping))
    body |> Stream.map(fn
        {mod, call, cpars} -> handle_call(mod, call, cpars, mapping, rules, facts, level)
        {call, cpars} -> handle_call(call, cpars, mapping, rules, facts, level)
      # fn currentset ->
      #   lcargs = M.maplocal(mapping, cpars, level)
      #   potsub = currentset
      #   |> Enum.map(fn m -> {m, lcargs |> Enum.map(fn l -> Map.get(m, l, l) end)}  end)
      #   #IO.puts(inspect([cs: currentset, args: args, cpars: cpars, potsub: potsub]))
      #   potsub
      #   |> Enum.map(fn {m, ps} -> resolveX(call, ps, rules, facts, level)
      #         |> inject_keys(m) end)
      #   |> Enum.reduce(default(), fn e, a -> comb(e, a) end)
      # end # fn currentset
    end)
    |> Enum.reduce_while([%{}], fn r, acc ->
      case r.(acc) do
        {false, _} -> {:halt, {:localfail, acc}}
        {true, localresult} -> joinr = join(acc, localresult)
            case joinr do
              []  -> {:halt, {:joinfail, acc}}
              _   -> {:cont, joinr}
            end
      end
    end)
    |> case do
      r when is_list(r) -> {true, r }
      {_failcause, fr} -> {false, fr}
    end
  end

  def handle_call(call, cpars, mapping, rules, facts, level) do
    lcargs = M.maplocal(mapping, cpars, level)
    fn currentset ->
      potsub = currentset
      |> Enum.map(fn m -> {m, lcargs |> Enum.map(fn l -> Map.get(m, l, l) end)}  end)
      #IO.puts(inspect([cs: currentset, args: args, cpars: cpars, potsub: potsub]))
      potsub
      |> Enum.map(fn {m, ps} -> resolveX(call, ps, rules, facts, level)
              |> inject_keys(m) end # mapping as reduce acc
            )
      |> Enum.reduce(default(), fn e, a -> comb(a, e) end)
    end # fn currentset
  end

  def handle_call(:not, call, cpars, mapping, rules, facts, level) do
    fn currentset ->
      lcargs = M.maplocal(mapping, cpars, level)
      potsub = currentset
      |> Enum.map(fn m -> {m, lcargs |> Enum.map(fn l -> Map.get(m, l, l) end)}  end)
      #IO.puts(inspect([cs: currentset, cpars: cpars, potsub: potsub]))
      ibt = potsub
      |> Enum.map(fn {m, ps} -> case resolveX(call, ps, rules, facts, level) do
        {true, tr} -> {false, tr}
        {false, _fr} -> {true, [m]}
      end
            #|> inject_keys(m)
          end)
      #IO.puts(inspect(ibt))
      ibt |> Enum.reduce(default(), fn e, a -> comb( a, e) end)  # collect m? failed m
    end # fn currentset
  end # handle_call

  # def inject_keys({false, _} = r, _), do: r
  # def inject_keys(r, map) when is_map(map) and map_size(map) == 0, do: r
  # def inject_keys({true, ml}, map) when is_list(ml) and is_map(map) do
  #   {true, Enum.map(ml, fn m -> Map.merge(m, map) end)}
  # end

  #def inject_keys({false, _} = r, _), do: r
  def inject_keys(r, map) when is_map(map) and map_size(map) == 0, do: r
  def inject_keys({tf, ml}, map) when is_list(ml) and is_map(map) do
    {tf, Enum.map(ml, fn m -> Map.merge(m, map) end)}
  end

  def join(lhs, []), do: lhs
  def join(lhs, [%{} = m]) when map_size(m) == 0, do: lhs
  def join(lhs, rhs) do
     ( for l <- lhs, r <-rhs, do: M.mmerge(l, r) ) |> Enum.filter(&(&1 != nil))
  end

  def drop_not(map, keys) when is_map(map) and is_list(keys) do
    #IO.puts(inspect({map, keys}))
    Map.drop(map, Map.keys(map) |> Enum.filter(fn k -> not Enum.any?(keys, fn l -> l == k end) end))
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
