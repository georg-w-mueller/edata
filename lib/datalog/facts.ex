defmodule Edata.Datalog.Facts do
  defstruct map: %{}, expand_streams: true
  alias __MODULE__, as: F
  alias Edata.Datalog.Misc, as: M

  def new(), do: %F{}
  def new(m), do: %F{map: m}

  # quote do parent(adam, bertram) end
  # => {:parent, [], [{:adam, [], Elixir}, {:bertram, [], Elixir}]}

  def add(%F{} = fts, {:__block__, _context, _arglist} = many) do
    M.parse_body(many)
    |> Enum.reduce(fts, fn f, acc -> add(acc, f) end)
  end

  def add(%F{ } = fts, {pred, _context, arglist}), do: add(fts, {pred, arglist})

  def add(%F{ map: m , expand_streams: exp}, {pred, arglist}) do
    sl = Enum.map(arglist,
      fn  {:.., _context, [_start, _end]} = str -> M.parse_body(str)
          {e, _c, _x }  -> Atom.to_string(e)
          x -> x  # keep, if no preparation required
      end)
    nm = Map.update(m, pred, exp_ifreq(sl, exp, []), fn lst -> exp_ifreq(sl, exp, lst) end)
    new(nm)
  end

  def factsfor(%F{ map: m }, pred) when is_atom(pred), do: Map.get(m, pred, [])

  def factsfor(%F{} = this, {pred, arity}) when is_atom(pred) and is_integer(arity) do
    factsfor(this, pred) |> Stream.filter(&(length(&1) == arity))
  end
  # quote do parent(X,Y) end
  # => {:parent, [], [{:__aliases__, [alias: false], [:X]}, {:__aliases__, [alias: false], [:Y]}]}

  def askf(%F{ map: _m } = fcs, {pred, _context, arglist}), do: resolve(fcs, pred, M.exarglist(arglist))

  def resolve(%F{} = _fcs, :eq, []), do: {true, []}
  #def resolve(%F{} = _fcs, :eq, [hd | _] = al) when is_atom(hd), do: IO.puts(inspect({:EQ, hd}))
  def resolve(%F{} = _fcs, :eq, [hd | _] = al) do
    {al |> Enum.all?(&(&1 == hd)), []}
  end
  def resolve(%F{} = fcs, pred, arglist) do
    relfs = factsfor(fcs, pred)
    case bind(arglist, relfs) do
      [] -> {false, []}
      #[map] -> case map_size(map) do
      #  0 -> {true, []}
      #  _ -> {true, [map]}
      #end
      r -> {true, r}
    end
  end

  def bind(al, cands) do
    for c <- cands do
      Enum.zip(al, c)
      |> Enum.reduce(%{},
          fn _, nil -> nil
            {l, r}, mp when is_atom(l) -> case Map.get(mp, l) do
                  nil -> Map.put(mp, l, r)
                  ov -> if ov == r, do: mp, else: nil
                end # case
            {l, r}, mp # when is_binary(l)
                -> if l == r, do: mp, else: nil
          end)
    end |> Enum.filter(&(&1 != nil))
  end

  def resolve_stream(%F{} = fcs, :eq, arglist) do
    case resolve(fcs, :eq, arglist) do
      {true, _} -> [%{}]
      _ -> []
    end
  end

  def resolve_stream(%F{} = fcs, pred, arglist) do
    factsfor(fcs, pred) |> bind_stream(arglist)
  end

  def bind_stream(cands, al) do
    Stream.map(cands, fn c -> bindc(al, c)
    #   Enum.zip(al, c)
    #   |> Enum.reduce(%{},
    #       fn _, nil -> nil
    #         {l, r}, mp when is_atom(l) -> case Map.get(mp, l) do
    #               nil -> Map.put(mp, l, r)
    #               ov -> if ov == r, do: mp, else: nil
    #             end # case
    #         {l, r}, mp # when is_binary(l)
    #             -> if l == r, do: mp, else: nil
    #       end)
    end) |> Stream.filter(&(&1 != nil))
  end

  def bindc(al, c) do
    case al == c do
      true -> %{}
      _ -> if length(al) <= length(c), do: bindc_(al, c, %{}), else: nil
    end
  end

  def bindc_([], _c, mp), do: mp
  def bindc_([l | lrest], [r | rrest], mp) when is_atom(l) do
    case Map.get(mp, l) do
      nil -> bindc_(lrest, rrest, Map.put(mp, l, r))
      ov -> if ov == r, do: bindc_(lrest, rrest, mp), else: nil
    end # case
  end
  def bindc_([l | lrest], [r | rrest], mp) when l == r, do: bindc_(lrest, rrest, mp)
  def bindc_(_, _, _), do: nil

  def exp_ifreq(cand, exp, prior) do
    prior ++
    if exp && is_streaming?(cand), do: expand(cand), else: [cand]
  end

  def is_streaming?(cand) do
    cand |> Enum.any?(
      fn {:stream, _str} -> true
        _ -> false
    end)
  end

  def expand(cand) do
    Stream.zip(cand |> Enum.map(
      fn {:stream, str} -> str
         x -> Stream.cycle([x])
    end )) |> Enum.map(&(:erlang.tuple_to_list(&1)))
  end

  alias Edata.Datalog.Base.Ask
  defimpl Ask, for: F do
    def ask?(_f), do: true
    def ask(target, question), do: F.askf(target, question)
  end
end # module
