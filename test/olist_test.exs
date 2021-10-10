defmodule OlistTest do
  use ExUnit.Case
  doctest Edata

  import Edata.Olist

  test "Enum / insert" do
    assert  %Edata.Olist{
        data: [
          {1, 1},
          {2, 2},
          {3, 3},
          {4, 4},
          {5, 5},
          {5.5, "x"},
          {6, 6},
          {7, 7},
          {8, 8},
          {9, 9}
        ],
        max_key: 9,
        min_key: 1,
        size: 10,
        ascending: true
      } == (for x <- 9..1, do: {x, x}) |> Enum.into( Edata.Olist.new()) |> keystore({5.5, "x"})
  end

  test "Enum / insert - ascending: false" do
    assert %Edata.Olist{
      ascending: false,
      data: [
        {9, 9},
        {8, 8},
        {7, 7},
        {6, 6},
        {5.5, "x"},
        {5, 5},
        {4, 4},
        {3, 3},
        {2, 2},
        {1, 1}
      ],
      max_key: 9,
      min_key: 1,
      size: 10,
    } == (for x <- 1..9, do: {x, x}) |> Enum.into( Edata.Olist.new(false)) |> keystore({5.5, "x"})
  end

  test "Enum / reduce" do
    assert [{1, 1}, {2, 2}, {3, 3}, {4, 4}, {5, 5}, {6, 6}, {7, 7}, {8, 8}, {9, 9}] ==
    (for x <- 1..9, do: {x, x}) |> Enum.into( Edata.Olist.new(false)) |> Enum.reduce([], fn e, acc -> [e | acc] end)
  end
end
