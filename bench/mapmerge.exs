defmodule MM do
  def mmerge(lhs, rhs) when is_map(lhs) and is_map(rhs) do
    mmerge( lhs, rhs, Map.keys(lhs) |> Enum.filter(& (Map.has_key?(rhs, &1)) ))
  end
  def mmerge(lhs, rhs, common) when is_map(lhs) and is_map(rhs) and is_list(common) do
    case Enum.any?(common, fn c -> Map.get(lhs, c) != Map.get(rhs, c) end) do
      true -> nil
      false -> Map.merge(lhs, rhs)
    end
  end

  def lmerge(lhs, rhs) when is_list(lhs) and is_list(rhs) do
    mmerge( lhs, rhs, Keyword.keys(lhs) |> Enum.filter(& (Keyword.has_key?(rhs, &1)) ))
  end
  def mmerge(lhs, rhs, common) when is_list(lhs) and is_list(rhs) and is_list(common) do
    case Enum.any?(common, fn c -> Keyword.get(lhs, c) != Keyword.get(rhs, c) end) do
      true -> nil
      false -> Keyword.merge(lhs, rhs)
    end
  end
end

base = ?a..?z
input = base |> Stream.map(&({ :erlang.list_to_atom([&1]), &1  })) |> Enum.to_list
# reducer = &(Enum.count(&1))

Benchee.run(%{
  "mmerge" => fn -> Enum.reduce(input, Map.new(), fn e, acc -> MM.mmerge(acc, Map.new([e])) end) end,
  "mmerge prefilled" => fn -> Enum.reduce(input, Map.new(input), fn e, acc -> MM.mmerge(acc, Map.new([e])) end) end,
  "lmerge" => fn -> Enum.reduce(input, Keyword.new(), fn e, acc -> MM.lmerge(acc, Keyword.new([e])) end) end,
  "lmerge prefilled" => fn -> Enum.reduce(input, Keyword.new(input), fn e, acc -> MM.lmerge(acc, Keyword.new([e])) end) end
})
