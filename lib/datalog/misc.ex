defmodule Edata.Datalog.Misc do

  alias Edata.StreamSplit, as: SS

# quote do parent(X,Y) end
# => {:parent, [], [{:__aliases__, [alias: false], [:X]}, {:__aliases__, [alias: false], [:Y]}]}

  def exarglist(arglist) do
    Enum.map(arglist,
      fn  {:__aliases__, _c, [v] }  -> v
          {e, _c, _x} -> Atom.to_string(e)
          x when is_integer(x) -> x
      end)
  end

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

  def parse_rule([{:->, [], [ [fhead], fbody ]}]) do
    # IO.puts(inspect (fhead))
    {pred, _context, arglist} = fhead
    args = exarglist(arglist)
    #IO.puts(inspect (pred))
    #IO.puts(inspect (args))
    body = parse_body(fbody)
    #IO.puts(inspect (body))
    {pred, args, body}
  end

  def parse_body({:__block__, [], pts}) when is_list(pts) do
    Enum.reduce(pts, [], fn p, r -> r ++ parse_body(p) end)
  end

#   iex(535)> quote do not eq(A, B) end
# {:__block__, [],
#  [
#    {:not, [context: Elixir, import: Kernel],
#     [
#       {:eq, [],
#        [
#          {:__aliases__, [alias: false], [:A]},
#          {:__aliases__, [alias: false], [:B]}
#        ]}
#     ]}
#  ]}

  def parse_body({:.., _, [_start, _end]} = expr), do: {:stream, expr |> Code.eval_quoted() |> elem(0)}

  def parse_body({:not, _, pts}) when is_list(pts) do
    Enum.reduce(pts, [], fn p, r -> r ++ parse_body(p, :not) end)
  end
  def parse_body({:any, _, pts}) when is_list(pts) do
    Enum.reduce(pts, [], fn p, r -> r ++ parse_body(p, :any) end)
  end
  def parse_body({single, [], arglist}) when is_atom(single) do
    [ {single, exarglist(arglist)} ]
  end

  def parse_body({single, [], arglist}, mod) when is_atom(single) do
    [ {mod, single, exarglist(arglist)} ]
  end

  def mmerge(lhs, rhs) when is_map(lhs) and is_map(rhs) do
    mmerge( lhs, rhs, Map.keys(lhs) |> Enum.filter(& (Map.has_key?(rhs, &1)) ))
  end
  def mmerge(lhs, rhs, common) when is_map(lhs) and is_map(rhs) and is_list(common) do
    case Enum.any?(common, fn c -> Map.get(lhs, c) != Map.get(rhs, c) end) do
      true -> nil
      false -> Map.merge(lhs, rhs)
    end
  end

  def distinct_r({i, l}) when is_boolean(i), do: {i, distinct(l)} # and is_list(l),

  def distinct(l)  do #when is_list(l)
    #MapSet.new(l)
    l |> Enum.reduce(MapSet.new(), fn e, m -> MapSet.put(m, remove_ukeys(e)) end) |> MapSet.to_list()
  end

  def atom_stwu(a) when is_atom(a) do
    a |> Atom.to_string() |> String.starts_with?("_")
  end

  def remove_ukeys(m) when is_map(m) do
    m |> Map.drop(
      Map.keys(m) |> Enum.filter(&(atom_stwu(&1)))
    )
  end

  def resolve_innerref(m) when is_map(m) do
    m |> Enum.map(fn
      {k, v} when is_atom(v) -> {k, m |> Map.get(v)}
      x -> x
    end)
    |> Enum.into(%{})
  end

 # rule(A, B) -> .. # rule paramenter, atoms
 # rule arguments .. given in query, atoms / binaries
  def mapargs(par, args) do
    Enum.zip(par, args)
    |> Enum.reduce(%{}, fn {p, a}, m -> Map.put(m, p, a) end)
  end

  def mapping_valid?(m) when is_map(m) do
    m |> Enum.all?(
      fn {k, v} when not is_atom(k) and not is_atom(v) -> k == v
        _ -> true
    end)
  end

  def omap(m) when is_map(m) do
    m |> Enum.reduce(%{},
    fn {k, v}, r when not is_atom(k) and is_atom(v) -> Map.put(r, v, k)
      _, r -> r
    end)
  end

  def callmap(), do: Map.new()

  def ccmap(m, {call, ps, elapsed}) when is_map(m) and is_atom(call) and is_list(ps) do
    m |> Map.update( {call, ps}, {1, elapsed}, fn {n, el} -> {n+1, el + elapsed} end )
  end

  def loop(ccm, rec) do
    receive do
      {:stop, add} -> send add, ccm
      :stop -> send rec, ccm
      {_call, _ps, _elapsed} = msg -> loop(ccm |> ccmap(msg), rec)
    end
  end

  def init_loop(rec \\ nil) do
    nrec = rec || self()
    spawn(fn -> loop(callmap(), nrec) end)
  end

  def yield() do
    receive do
      m when is_map(m) -> m
    after 0 -> %{}
    end
  end

  def yeval() do
    yield() |> Enum.to_list |> lsort(fn {{_ca, _la,}, {na,  _ela}}, {{_cb, _lb}, {nb, _elb}} -> na >= nb end)# <= .. ascending
  end

  def lsort(list, sortf), do: :lists.sort(sortf, list)

# iex(383)> Rules.ask_using(m2, ints, quote do add(0, 0, A) end)
# {:call, :add, [0, 0, :A], 0}
# {:mapargs, [:A, :B, :B], [0, 0, :A]}
# :dupfail
# {:mapargs, [:A, :B, :A], [0, 0, :A]}
# :dupfail
# {:result, :add, [0, 0, :A], 0, {false, []}}
# {false, []}

  def maplocal(map, localpar, level \\0)

  def maplocal(map, localpar, level) when is_map(map) and is_list(localpar) do
    localpar |> Enum.map(fn l -> Map.get(map, l, l |> rise_atom(level)) end)
  end

  def maplocal(mapping, localpar, level) when is_list(mapping) and is_list(localpar) do
    maploca_(mapping, localpar, level, [])
  end

  def maploca_(_mapping, [], _level, res), do: :lists.reverse(res)
  def maploca_(mapping, [l | lrest], level, res) do
    case Keyword.get(mapping, l) do
      nil -> maploca_(mapping, lrest, level, [l |> rise_atom(level) | res])
      val -> maploca_(
        Keyword.delete_first(mapping, l), lrest, level, [val | res])
    end
  end

  def rise_atom(at, 0), do: at
  def rise_atom(at, level) when is_atom(at), do: ( String.duplicate("_", level) <> Atom.to_string(at) ) |> String.to_atom()
  def rise_atom(non_atom, _level), do: non_atom

  # [
  #   %{X: "c", Y: "e", _M: "d"},
  #   %{X: "b", Y: "d", _M: "c"},
  #   %{X: "a", Y: "c", _M: "b"}
  # ]

  def sufficently_equal(given, tocheck) when is_list(given) and is_list((tocheck)) do
    ( Enum.count(given) == Enum.count(tocheck) ) &&
    Enum.all?(given,
      fn g -> Enum.any?(tocheck,
        fn c -> Map.keys(g) |> Enum.all?(fn gk -> Map.get(g, gk) == Map.get(c, gk) end)  end)
      end)
  end

  def stream_ccross(left, right, cross_fun, filter \\ &(&1 != nil)) when is_function(cross_fun, 2) do
    case left |> Enum.take(1) do
      [] -> []
      [fl] ->
        s1 = right |> Stream.map(fn e -> {:__pack, fl, e} end)
        s2 = left |> Stream.drop(1)
        Stream.transform(
          Stream.concat( s1, s2 ), [],
          fn {:__pack, l, r}, acc ->
                {[ cross_fun.(l, r)], acc ++ [ r ]}
            l, acc ->
                {Stream.map( acc, fn a -> cross_fun.(l, a) end ), acc}
          end
        ) |> Stream.filter(filter)
    end # case
  end

  def stream_cross(left, right, cross_fun \\ &{&1, &2}) when is_function(cross_fun, 2) do
    Stream.flat_map left, fn l ->
      Stream.flat_map right, fn r ->
        [ cross_fun.(l,r) ]
      end
    end
  end

  def empty?(stream) do
    case SS.take_and_drop(stream, 1) do
      {[], _} -> {true, []}
      {[_] = hd, rest} -> {false, hd |> Stream.concat( rest )}
    end
  end

  # def is_done?(%{done: :done}), do: true
  # def is_done?(%{done: nil}), do: false
  def is_done?(%{done: done}), do: IO.inspect(done)

  def coll_stream_iterator(stream, coll \\ []) when is_list(coll) do
    fn :init -> stream_next(stream, coll)
        {_r, c, s} -> stream_next(s, c)
    end
  end

  def stream_next(stream, coll \\ []) when is_list(coll) do
    case Stream.take(stream, 1) |> Enum.to_list() do
      [] -> {:fail, coll, stream}
      [e] -> {:ok, [e | coll], Stream.drop(stream, 1)}
    end
  end

  def coll_stream(stream) do
    Stream.resource(
      fn ->  itf = coll_stream_iterator(stream); {itf, itf.(:init), :cont} end,
      fn  :fin -> {:halt, nil}
          { itf,  cr, :cont} -> case cr do
                {:ok, [h |_], _s} = r -> {[h], {itf, itf.(r), :cont }}
                {:fail, l, _s} -> { [{:last, :lists.reverse(l)}], :fin}
              end # case cr
      end,
      fn _ -> nil end
    )
  end

  def stream_cross_wi(left, right, cross_fun \\&({&1, &2})) when is_function(cross_fun, 2) do
    Stream.flat_map(Stream.with_index(left),
    fn {l,0} ->
      Stream.flat_map right, fn r ->
        [ {:__collect, r, cross_fun.(l,r) } ]
      end
       lewi -> [ lewi ]
    end)
    |> Stream.transform([],
    fn  {:__collect, r, res }, acc -> {[ res ], [r | acc]}
        {l, 1}, acc ->
          rac = :lists.reverse(acc)
          {Stream.map( rac, fn a -> cross_fun.(l, a) end ), rac}
        {l, _}, acc -> {Stream.map( acc, fn a -> cross_fun.(l, a) end ), acc}
    end)
  end

  def distinct_mapset(enum) do
    Stream.transform(enum, MapSet.new(),
    fn e, acc ->
      if MapSet.member?(acc, e), do: {[], acc}, else: {[e], acc |> MapSet.put(e) }
    end)
  end

  def distincttl(enum) do
    enum |> distinct_mapset() |> Enum.to_list()
  end

end
