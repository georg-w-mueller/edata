defmodule TransducerTest do
  use ExUnit.Case
  doctest Edata

  import Edata.Transducer

  test "count" do
    assert 3 == count() |> reduce([2, 4, 6])
  end

  test "to_list" do
    assert [2, 4, 6] == to_list() |> reduce([2, 4, 6])
  end

  test "filter / to_list" do
    assert [2, 4, 6] == filter(fn e -> rem(e, 2) == 0 end).(to_list()) |> reduce([1, 2, 3, 4, 5, 6])
  end

  test "map / to_list" do
    assert [2, 4, 6, 8, 10, 12] == map(fn e -> e * 2 end).(to_list()) |> reduce([1, 2, 3, 4, 5, 6])
  end

  test "map + filter / to_list (1)" do
    times4 = map(fn e -> e * 4 end)
    evenf = filter(fn e -> rem(e, 2) == 0 end)
    reducer = to_list()

    assert [8, 16] == reducer |> times4.() |> evenf.() |> reduce([1, 2, 3, 4])
    assert [4, 8, 12, 16] == reducer |> evenf.() |> times4.() |> reduce([1, 2, 3, 4])
  end

  test "take + filter (1)" do
    even = filter(&( rem(&1,2 ) == 0))
    t2 = take(2)
    assert [2] == to_list() |> t2.() |> even.() |> reduce([1, 1, 2, 1])
    assert []  == to_list() |> even.() |> t2.() |> reduce([1, 1, 2, 1])
  end

  test "take + map + filter / to_list" do
    even = filter(&( rem(&1,2 ) == 0))
    times2 = map( &(&1*2) )
    t2 = take(2)
    assert [2, 4] == to_list() |> even.() |> times2.() |> t2.() |> reduce([1, 2, 3, 4])
    assert [2, 4] == to_list() |> t2.() |> even.() |> reduce([1, 2, 3, 4, 5, 6])
  end

  test "drop" do
    drop3 = drop(3)
    assert [] = to_list() |> drop3.() |> reduce([1, 2, 3])
    assert [4, 5] == to_list() |> drop3.() |> reduce([1, 2, 3, 4, 5])
  end

  test "partition" do
    peven = partition(&( rem(&1, 2)==0 ))
    assert [] == to_list() |> peven.() |> reduce([])
    assert [[1]] == to_list() |> peven.() |> reduce([1])
    assert [[1, 1]] == to_list() |> peven.() |> reduce([1, 1])
    assert [[1], [2]] == to_list() |> peven.() |> reduce([1, 2])
    assert [[1, 1, 1], [2], [3]] == to_list() |> peven.() |> reduce([1, 1, 1, 2, 3])

    times4 = map(&(&1 * 4))
    assert [[4, 8, 12, 16]] == to_list() |> peven.() |> times4.() |> reduce([1, 2, 3, 4])
  end

  test "partition + map" do
    ml = map(&(length(&1)))
    assert [1, 2, 3, 4, 1] ==to_list() |> ml.() |> partition(&( rem(&1, 2)==0 )).() |> reduce([1, 2, 2, 3, 3, 3, 4, 4, 4, 4, 5])
  end

  test "keep_last" do
    assert [2, 3] == to_list() |> keep_last(2).() |> reduce([1,2,3])
  end

  test "reduce_generic" do
    assert [5, 10, 15, 20, 25] == to_list() |> map(&(&1*5)).() |> reduce_generic(1..5)
    assert [2, 4] == to_list() |> filter(&( rem(&1, 2) == 0)).() |> reduce_generic(1..5)
    assert 10 == count() |> reduce_generic(1..10)
  end

  test "generic + take + partition" do
    peven = partition(&( rem(&1, 2)==0 ))
    assert [[1], [2]] == to_list() |> peven.() |> take(2).() |> reduce_generic(1..5)
    assert [[1]] == to_list() |> take(1).() |> peven.() |> reduce_generic(1..5)

    assert [[4, 8, 12, 16, 20]] == to_list() |> peven.() |> map(&(&1*4)).() |> reduce_generic(1..5)
  end

  test "keep_last + partition" do
    peven = partition(&( rem(&1, 2)==0 ))
    assert [[3]] == to_list() |> keep_last(1).() |> peven.() |> keep_last(1).() |> reduce_generic([1, 1, 2, 2, 3, 3])
    assert [[3, 3]] == to_list() |> keep_last(1).() |> peven.() |> reduce_generic([1, 1, 2, 2, 3, 3])
  end

  test "altogether" do
    peven = partition(&( rem(&1, 2)==0 ))
    assert [[4, 4, 4], [5, 5, 5, 5]] ==
    to_list() |> filter(&(length(&1) > 2)).() |> keep_last(99).() |> peven.() |> map(&(&1+1)).() |> reduce_generic([1, 2, 2, 3, 3, 3, 4, 4, 4, 4])
  end

  test "roundrobin" do
    assert [
      [100, 400, 700, 1000, 1300],
      [200, 500, 800, 1100, 1400],
      [300, 600, 900, 1200, 1500]
    ] == to_list() |> roundrobin(3).() |> map(&(&1*100)).() |> reduce_generic(1..15)
  end

  test "unpack + rr" do
    assert [1, 6, 11, 2, 7, 12, 3, 8, 13, 4, 9, 14, 5, 10, 15] ==
      to_list() |> unpack().() |> roundrobin(5).() |> reduce_generic(1..15)
  end

  test "rr + unpack + take" do
    assert [1] == to_list() |> take(1).() |> unpack().() |> roundrobin(2).() |> reduce_generic(1..10)
    assert [1, 3, 5, 7, 9] == to_list() |> unpack().() |> take(1).() |> roundrobin(2).() |> reduce_generic(1..10)
    assert [3, 6, 9] == to_list() |> unpack().() |> drop(2).() |> roundrobin(3).() |> reduce_generic(1..10)
  end

  test "constructed join with map & unpack" do
    join_pred = fn left, right -> left == right end
    join_comb = fn left, right -> {left, right} end
    joinlist = [2, 3] # right hand side

    mapper = fn e ->
      for el <- [e],
      er <- joinlist,
        join_pred.(el, er) do
          join_comb.(el, er)
        end
     end

     assert [{2, 2}, {3, 3}] == to_list() |> unpack().() |> map(mapper).() |> reduce_generic(1..4)
  end

  test "join_enum 1" do
    join_pred = fn left, right -> left == right end
    join_comb = fn left, right -> {left, right} end
    joinlist = [2, 3] # right hand side

    assert [{2, 2}, {3, 3}] == to_list() |> join_enum(joinlist, join_pred, join_comb).() |> reduce_generic(1..4)
  end

  test "join_trans 1" do
    rhs = fn x -> filter(fn e -> e>=2 && e<=3 end).(x) |> reduce_generic(1..4) end
    assert [2, 3] == to_list() |> rhs.()  # ensure rhs works correctly

    join_pred = fn left, right -> left == right end
    join_comb = fn left, _right -> left end
    assert [2, 3] == to_list() |> join_trans(rhs, join_pred, join_comb).() |> reduce_generic(1..4)
  end

  test "group 1" do
    assert [[1, 1], [2, 2], [3, 3]] == to_list() |> group(&(&1)).() |> reduce([3, 2, 1, 2, 3, 1])
  end

  test "sort 1" do
    assert [1, 1, 2, 2, 3, 3, 4] == to_list() |> sort(&(&1)).() |> reduce([4, 3, 2, 1, 2, 3, 1])
    assert [3, 4] == to_list() |> drop(5).() |> sort(&(&1)).() |> reduce([4, 3, 2, 1, 2, 3, 1])
    assert [3, 4] == to_list() |> keep_last(2).() |> sort(&(&1)).() |> reduce([4, 3, 2, 1, 2, 3, 1])
  end
end # module
