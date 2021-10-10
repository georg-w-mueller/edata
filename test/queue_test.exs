defmodule QueueTest do
  use ExUnit.Case
  doctest Edata

  import Edata.Queue

  test "Enum.into" do
    assert %Edata.Queue{front: [], length: 5, tail: [5, 4, 3, 2, 1]} == Enum.into(1..5, new())
  end

  test "Enum.to_list" do
    assert [1, 2, 3, 4, 5] == Enum.into(1..5, new()) |> Enum.to_list
  end

  test "take from empty" do
    assert_raise RuntimeError, fn -> new() |> take end
  end

  test "length + empty" do
    assert 0 == new() |> size
    assert 1 == new() |> add(:q) |> size

    assert new() |> empty?
    refute new() |> add(:q) |> empty?
  end

  test "dropfirst" do
    assert 0 == new() |> dropfirst() |> size()
    assert %Edata.Queue{front: [2, 3, 4, 5], length: 4, tail: []} == Enum.into(1..5, new()) |> dropfirst()
  end

end # module
