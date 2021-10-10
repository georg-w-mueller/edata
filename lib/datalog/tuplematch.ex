defmodule Edata.Datalog.Tuplematch do

  def tbind(t1, t2), do: tbind(t1, t2, %{}, %{})

  def tbind(t1, t2, _out, _mapping) when tuple_size(t1) != tuple_size(t2), do: nil
  def tbind(t1, t2, out, mapping) do
    txbind(t1, t2, out, mapping, 0)
  end

  def txbind(pt, _at, out, mapping, n) when n + 1 > tuple_size(pt), do: {out, mapping}
  def txbind(pt, at, out, mapping, n) do
    #IO.inspect(n)
    p = elem(pt, n)
    case is_atom(p) do
      true ->
        txbind(pt, at, out, Map.put(mapping, p, elem(at, n)), n + 1)
      _ ->
        a = elem(at, n)
        case is_atom(a) do
          true -> txbind(pt, at, Map.put(out, a, p), mapping, n + 1)
          _ -> if p != a, do: nil, else: txbind(pt, at, out, mapping, n + 1)
        end
    end
  end

  def lbind(l1, l2) do
    l1 |> Stream.zip(l2)
    |> Enum.reduce({ %{}, %{} },    ## out, regular mapping
    fn _, nil -> nil
      {p, a}, {o, r} when is_atom(p) -> {o, Map.put(r, p, a)}
      {p, a}, {o, r} when is_atom(a) -> {Map.put(o, a, p), r}
      {p, a}, m -> if p != a, do: nil, else: m
    end)
  end

  def lbind_w(l1, l2) do
    l1 |> Stream.zip(l2)
    |> Enum.reduce_while({ %{}, %{} },    ## out, regular mapping
    fn
      {p, a}, {o, r} when is_atom(p) -> {:cont, {o, Map.put(r, p, a)}}
      {p, a}, {o, r} when is_atom(a) -> {:cont, {Map.put(o, a, p), r}}
      {p, a}, m -> if p != a, do: {:halt, nil}, else: {:cont, m}
    end)
  end

  def lbind_c(l1, l2) when length(l1) != length(l2), do: nil
  def lbind_c(l1, l2), do: lbind_c(l1, l2, %{}, %{})

  def lbind_c([], _l2, out, mapping), do: {out, mapping}
  def lbind_c([p | pt], [a | at], out, mapping) do
    case is_atom(p) do
      true ->
        lbind_c(pt, at, out, Map.put(mapping, p, a))
      _ ->
        case is_atom(a) do
          true -> lbind_c(pt, at, Map.put(out, a, p), mapping)
          _ -> if p != a, do: nil, else: lbind_c(pt, at, out, mapping)
        end
    end
  end

  def lbind_c_kw(l1, l2) when length(l1) != length(l2), do: nil
  def lbind_c_kw(l1, l2), do: lbind_c_kw(l1, l2, %{}, [])

  def lbind_c_kw([], _l2, out, mapping), do: {out, :lists.reverse(mapping)}
  def lbind_c_kw([p | pt], [a | at], out, mapping) do
    case is_atom(p) do
      true ->
        lbind_c_kw(pt, at, out, [{p, a} | mapping] ) # Keyword.put(mapping, p, a)
      _ ->
        case is_atom(a) do
          true -> lbind_c_kw(pt, at, Map.put(out, a, p), mapping) #
          _ -> if p != a, do: nil, else: lbind_c_kw(pt, at, out, mapping)
        end
    end
  end

  def lsts_tt(enum), do: enum |> Enum.map(&(:erlang.list_to_tuple(&1)))

  def nkicks(n, len, gxb \\ nil) do
    xb = gxb || xbase()
    Stream.unfold(n, fn
      0 -> nil
      c -> { xlen(len, xb), c - 1}
    end) |> Enum.to_list
  end

  def xlen(n, gxb \\ nil) do
    xb = gxb || xbase()
    ml = length(xb)
    # for _ <- n, do: xb |> Enum.at(:rand.uniform(ml) - 1)
    Stream.unfold(n,
    fn 0 -> nil
       c -> {xb |> Enum.at(:rand.uniform(ml) - 1), c - 1}
    end) |> Enum.to_list()
  end

  def xbase() do
    1..10 |> Stream.concat([:A, :B, :C, :D, :E, :F, :G, :H, :I]) |> Enum.to_list
  end

  def mcontains(k, map) do
    case map[k] do
      nil -> nil
      value -> {:ok, value}
    end
  end
  # def mcontains(k, map), do: nil
end # module
