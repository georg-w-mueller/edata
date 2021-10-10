defmodule EdataTest do
  use ExUnit.Case
  doctest Edata

  import Edata.Btree

  test "greets the world" do
    assert Edata.hello() == :world
  end

  test "basic new" do
    assert %Edata.Btree{tree: {0, nil}} == new()
  end

  test "new with list" do
    assert %Edata.Btree{tree: {2, {:b, 2, {:a, 1, nil, nil}, nil}}} == new([{:a, 1}, {:b, 2}])
  end

  test "has key" do
    assert new([{:a, 1}, {:b, 2}]) |> has_key?(:b)
    refute new([{:a, 1}, {:b, 2}]) |> has_key?(:c)
  end

  test "fetch" do
    assert {:ok, 2} == new([{:a, 1}, {:b, 2}]) |> fetch(:b)
    assert {:error, nil} == new([{:a, 1}, {:b, 2}]) |> fetch(:c)
  end

  test "put" do
    t = new() |> put(1, 1) |> put(2, 2)
    assert {:ok, 1} == t |> fetch(1)
    assert {:ok, 2} == t |> fetch(2)
  end

  test "delete" do
    assert {:error, nil} == new() |> put(1, 1) |> delete(1) |> fetch(1)
  end

  test "keys" do
    assert [1, 2, 3, 4, 5] == new(for x <- 1..5, do: {x, x} ) |> keys
  end

  test "values" do
    assert [-1, -2, -3, -4, -5] == new(for x <- 1..5, do: {x, -x} ) |> values
  end

  test "size" do
    assert 5 == new(for x <- 1..5, do: {x, -x} ) |> size
  end

  test "to list" do
    assert [{:a, 1}, {:b, 2}] == new([{:a, 1}, {:b, 2}]) |> to_list
  end

  test "member {key, value}" do
    assert new([{:a, 1}, {:b, 2}]) |> member?(:b, 2)
  end

  test "stream" do
    assert [a: 1, b: 2] == new([{:a, 1}, {:b, 2}]) |> stream |> Enum.take(2)
  end

  test "stream with start" do
    assert [b: 2, c: 3] == new([{:a, 1}, {:b, 2}, {:c, 3}]) |> stream(:b) |> Enum.take(2)
  end

  test "stream_rev with start" do
    assert [{5, 5}, {4, 4}, {3, 3}, {2, 2}, {1, 1}] == new( for x <- 1..10, do: {x, x} ) |> stream_rev(5) |> Enum.to_list
  end

  test "first" do
    assert {:error, nil} == new() |> first
    assert {:ok, {1, 1}} == new(for x <- 5..1, do: {x, x} ) |> first
  end

  test "last" do
    assert {:error, nil} == new() |> last
    assert {:ok, {5, 5}} == new(for x <- 5..1, do: {x, x} ) |> last
  end

  test "Enum.into" do
    assert 6 == (for x <- 5..10, do: {x, x}) |> Enum.into(new()) |> size
  end

  test "Enum / Collectable combined" do
    assert [{-10, 10}, {-9, 9}, {-8, 8}, {-7, 7}, {-6, 6}, {-5, 5}] ==
    (for x <- 5..10, do: {-x, x}) |> Enum.into(new()) |> Enum.to_list
  end
end
