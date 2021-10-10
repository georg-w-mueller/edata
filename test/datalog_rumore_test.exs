defmodule DatalogRumoreTest do
  use ExUnit.Case
  doctest Edata

  alias Edata.Datalog.Facts, as: F
  alias Edata.Datalog.Rumore, as: R
  alias Edata.Datalog.Misc, as: M

  test "pre_bound" do
    r0 = R.new() |> R.add(quote do add(0, 0, 0) -> eq() end)

    assert [{[], [eq: []], %{}}] == R.pre_bound(r0, :add, [0, 0, 0]) |> Enum.to_list    # pre_bound2
    assert [{[], [eq: []], %{Y: 0, Z: 0}}] == R.pre_bound(r0, :add, [0, :Y, :Z]) |> Enum.to_list
    assert [] == R.pre_bound(r0, :add, [1, 0, 0]) |> Enum.to_list

    r01 = r0 |> R.add(quote do add(0, 1, 1) -> eq() end) |> R.add(quote do add(1, 0, 1) -> eq() end)

    assert [
      {[], [eq: []], %{A: 1, B: 0, C: 1}},
      {[], [eq: []], %{A: 0, B: 1, C: 1}},
      {[], [eq: []], %{A: 0, B: 0, C: 0}}
    ] == R.pre_bound(r01, :add, [:A, :B, :C]) |> Enum.to_list

    assert [{[], [eq: []], %{A: 1, B: 0}},
            {[], [eq: []], %{A: 0, B: 1}}] == R.pre_bound(r01, :add, [:A, :B, 1]) |> Enum.to_list

    assert [{[], [eq: []], %{B: 0, C: 1}}] == R.pre_bound(r01, :add, [1, :B, :C]) |> Enum.to_list

    r01p = r01 |> R.add(quote do add(0, B, R) -> int(B); int(R) end)

    assert [
      {[:B, :R], [int: [:B], int: [:R]], %{X: 0, Y: :B, Z: :R}},
      {[], [eq: []], %{X: 1, Y: 0, Z: 1}},
      {[], [eq: []], %{X: 0, Y: 1, Z: 1}},
      {[], [eq: []], %{X: 0, Y: 0, Z: 0}}
    ] == R.pre_bound(r01p, :add, [:X, :Y, :Z]) |> Enum.to_list

    assert [
      {[:B, :R], [int: [:B], int: [:R]], %{0 => :B, :X => 0, :Z => :R}},
      {[], [eq: []], %{X: 1, Z: 1}},
      {[], [eq: []], %{X: 0, Z: 0}}
    ] == R.pre_bound(r01p, :add, [:X, 0, :Z]) |> Enum.to_list
  end
end
