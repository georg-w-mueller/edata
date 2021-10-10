defmodule V8treeTest do
  use ExUnit.Case
  doctest Edata

  import Edata.V8tree

  test "some .." do
    t = new(100) |> set(77, 77) |> set(88, 88)
    assert 100 = t |> size()
    assert 77 = t |> get(77)
    assert 88 = t |> get(88)
  end

  test "Collectable" do
    t64 = (for x <- 0..63, do: {x, x}) |> Enum.into(new(64))
    assert 2.0 == t64.levels
    assert (for x <- 0..63, do: x) |> Enum.all?(fn i -> i == get(t64, i) end)
  end

  test "Enumerable" do
    ntft = (for x <- 0..599, do: {x, x}) |> Enum.into(new(600))
    assert [0, 1, 2, 3, 4, 5, 6, 7, 8, 9] == ntft |> Enum.take(10)
    assert [590, 591, 592, 593, 594, 595, 596, 597, 598, 599] == ntft |> Enum.slice(-10, 10)
  end

  test "defaults +  update" do
    assert [[], [], [], [], "4", [], [], [], [], []] == new(10, []) |> set(4, "4") |> Enum.to_list
    assert [0, 0, 0, 0, 1, 0, 0, 0, 0, 0] == new(10, 0) |> update(4, fn e -> e+1 end ) |> Enum.to_list
  end

  test "iterator" do
    t129 = (for x <- 0..128, do: {x, x}) |> Enum.into(new(129))
    tx = t129 |> iterator() |> iterator_to_tree()

    assert Enum.all?(0..128, &( get(t129, &1) == get(tx, &1)  ))
  end

  test "update all" do
    t64 = (for x <- 0..63, do: {x, x}) |> Enum.into(new(64))
    t64p = t64 |> update( &(&1+1) )
    assert Enum.all?(0..63, fn e -> get(t64, e)+1 == get(t64p, e) end)
  end

end
