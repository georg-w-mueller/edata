defmodule DatalogTest do
  use ExUnit.Case
  doctest Edata

  alias Edata.Datalog.Facts
  alias Edata.Datalog.Rules
  alias Edata.Datalog.Misc

  test "Gen & Ask" do
    facts = Facts.new()
    |> Facts.add(quote do parent(adam, bertram); parent(caesar, egon); parent(selfpar, selfpar) end)

    assert {false, []} == facts |> Facts.askf(quote do parent(adam, eve) end)
    assert {false, []} == facts |> Facts.askf(quote do parent(dora, Y) end)

    assert {true, [%{:X => "adam"}]} == facts |> Facts.askf(quote do parent(X, bertram) end)
    assert {true, [%{:Y => "egon"}]} == facts |> Facts.askf(quote do parent(caesar, Y) end)
    assert {true, [%{:X => "selfpar"}]} == facts |> Facts.askf(quote do parent(X, X) end)

    {ind, bindings} = facts |> Facts.askf(quote do parent(A, B) end)
    assert ind
    assert Enum.any?(bindings, fn b -> b == %{:A => "adam", :B => "bertram"} end)
    assert Enum.any?(bindings, fn b -> b == %{:A => "caesar", :B => "egon"} end)
    assert Enum.any?(bindings, fn b -> b == %{:A => "selfpar", :B => "selfpar"} end)

    assert Facts.new() |> Edata.Datalog.Base.Ask.ask?
  end

  test "Basic Join" do
    facts = Facts.new() |> Facts.add(quote do edge(a, b); edge(b, c) end)

    {true, lhs} = Facts.askf(facts, quote do edge(X, M) end)
    {true, rhs} = Facts.askf(facts, quote do edge(M, Y) end)

    r = ( for l <- lhs, r <-rhs, do: Misc.mmerge(l, r, [:M]) ) |> Enum.filter(&(&1 != nil))
    assert r == [%{M: "b", X: "a", Y: "c"}]
  end

  test "Basic rule, facts" do
    facts = Facts.new() |> Facts.add(quote do edge(a, b); edge(b, c) end)
    rules = Rules.new() |> Rules.add(quote do connected(X, Y) -> edge(X, Y) end)

    assert {false, []} == Rules.ask_using(rules, facts, quote do cc(a, b) end)  # no cc-rule
    assert {true, [%{}]} = Rules.ask_using(rules, facts, quote do connected(a, b) end)
    {ok, r} = Rules.ask_using(rules, facts, quote do connected(A, B) end)
    assert ok
    assert [%{A: "b", B: "c"}, %{A: "a", B: "b"}] |> Misc.sufficently_equal(r)
  end

  test "Several Rulechecks" do
    facts = Facts.new() |> Facts.add(quote do edge(a,b); edge(b,c); edge(c,d); edge(d,e); edge(r,s) end)
    rules = Rules.new()
    |> Rules.add(quote do conn(X,Y) -> edge(X,Y) end)
    |> Rules.add(quote do conn(X,Y) -> edge(X,M); conn(M,Y) end)
    |> Rules.add(quote do dist2(X,Y) -> edge(X,M); edge(M,Y) end)

    assert {false, []} == Rules.ask_using(rules, facts, quote do conn(a, s) end)

    {ok, r} = Rules.ask_using(rules, facts, quote do dist2(X, Y) end)
    assert ok
    assert [ %{X: "c", Y: "e"}, %{X: "b", Y: "d"}, %{X: "a", Y: "c"} ]
    |> Misc.sufficently_equal(r)

    {ok, r} = Rules.ask_using(rules, facts, quote do conn(b, Y) end)
    assert ok
    assert [%{Y: "e"}, %{Y: "d"}, %{Y: "c"}]
    |> Misc.sufficently_equal(r)

    {ok, r} = Rules.ask_using(rules, facts, quote do conn(R, S) end)
    assert ok
    assert [
      %{R: "c", S: "e"}, %{R: "b", S: "e"}, %{R: "b", S: "d"},
      %{R: "a", S: "e"}, %{R: "a", S: "d"}, %{R: "a", S: "c"},
      %{R: "r", S: "s"}, %{R: "d", S: "e"}, %{R: "c", S: "d"},
      %{R: "b", S: "c"}, %{R: "a", S: "b"}
    ] |> Misc.sufficently_equal(r)
  end

  test "Math" do
    ints = Facts.new()
    |> Facts.add(quote do zero(0); int(0); int(1); int(2); int(3); int(4) end)  #;
    |> Facts.add(quote do inc(0, 1); inc(1, 2); inc(2, 3); inc(3, 4) end)
    mr = Rules.new()
    |> Rules.add(quote do dec(A, B) -> inc(B, A) end)
    #|> Rules.add(quote do ints(A, B, C) -> int(A); int(B); int(C) end)
    |> Rules.add(quote do equal(A, B) -> eq(A, B) end)
    |> Rules.add(quote do add(A, B, R) -> zero(B); int(A); int(R); equal(A, R) end)
    |> Rules.add(quote do add(A, B, R) -> zero(A); int(B); int(R); equal(B, R) end)
    |> Rules.add(quote do add(A, B, R) -> dec(A, AD); inc(B, BI); add(AD, BI, R) end)

    {ok, r} = Rules.ask_using(mr, ints, quote do add(A, B, R) end)
    assert ok
    assert [
      %{A: 0, B: 0, R: 0},
      %{A: 0, B: 1, R: 1},
      %{A: 0, B: 2, R: 2},
      %{A: 0, B: 3, R: 3},
      %{A: 0, B: 4, R: 4},
      %{A: 1, B: 0, R: 1},
      %{A: 1, B: 1, R: 2},
      %{A: 1, B: 2, R: 3},
      %{A: 1, B: 3, R: 4},
      %{A: 2, B: 0, R: 2},
      %{A: 2, B: 1, R: 3},
      %{A: 2, B: 2, R: 4},
      %{A: 3, B: 0, R: 3},
      %{A: 3, B: 1, R: 4},
      %{A: 4, B: 0, R: 4}
    ]  |> Misc.sufficently_equal(r)
  end

  test "sufficently_equal" do
    assert  [  %{X: "a", Y: "c"}, %{X: "c", Y: "e"}, %{X: "b", Y: "d"}]
    |> Misc.sufficently_equal(
            [  %{X: "c", Y: "e", _M: "d"}, %{X: "b", Y: "d", _M: "c"}, %{X: "a", Y: "c", _M: "b"}] )

    refute  [  %{X: "a", Y: "c"}, %{X: "c", Y: "e"}, %{X: "b", Y: "d"}]
            |> Misc.sufficently_equal(
            [  %{X: "c", Y: "e", _M: "d"}, %{X: "a", Y: "c", _M: "b"}] )

    refute  [  %{X: "a", Y: "caesar"}, %{X: "c", Y: "e"}, %{X: "b", Y: "d"}]
            |> Misc.sufficently_equal(
            [  %{X: "c", Y: "e", _M: "d"}, %{X: "b", Y: "d", _M: "c"}, %{X: "a", Y: "c", _M: "b"}] )
  end
end # module
