defmodule BenchDefs do
  @ir 1..6000
  def range(:ints), do: @ir
  def range(:binaries32),
    do: unquote(Enum.map(@ir, fn _ -> :crypto.strong_rand_bytes(32) end))

  def rd(<<>>, acc, _fun), do: acc
  def rd(<<h :: 8, t :: binary>>, acc, fun), do: rd(t, fun.(h, acc), fun)
end

defmodule Lsts do
  def lsts() do
    unquote(BenchDefs.range(:binaries32) |> Enum.map(fn b -> b |>  BenchDefs.rd([], fn e, acc -> acc ++ [e] end) end))
  end
  def rd([], acc, _fun), do: acc
  def rd([h | t], acc, fun), do: rd(t, fun.(h, acc), fun)
end

defmodule HeadDispatch do
  for i <- BenchDefs.range(:ints) |> Stream.zip(BenchDefs.range(:binaries32)) do
    {k, v} = i
    def match(unquote(k)), do: unquote(v)
  end
end

defmodule MapDispatch do
  @map Map.new(BenchDefs.range(:ints) |> Stream.zip(BenchDefs.range(:binaries32)))
  def match(x)  do
    Map.get(@map, x)
  end
end

Benchee.run(%{
  "List rd" => fn -> Lsts.lsts |> Enum.map(fn l -> l |> Lsts.rd(0, fn e, acc -> e + acc end) end) end,
  "Bin rd" => fn ->  BenchDefs.range(:binaries32) |> Enum.map(fn l -> l |> BenchDefs.rd(0, fn e, acc -> e + acc end) end) end
}, time: 40, parallel: 2)

# Benchee.run(%{
#   "HD" => fn -> BenchDefs.range(:ints) |> Stream.map(fn i -> HeadDispatch.match(i) end) |> Stream.run end,
#   "MP" => fn -> BenchDefs.range(:ints) |> Stream.map(fn i -> MapDispatch.match(i) end) |> Stream.run end
# }, time: 40, parallel: 2)
