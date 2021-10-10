defmodule Edata.Btree do
  @moduledoc """
  Wrapper for Erlangs :gb_trees-functions
  http://erlang.org/doc/man/gb_trees.html
  """

  alias __MODULE__, as: T

  defstruct [:tree]

  def new do
    %T{tree: :gb_trees.empty}
  end

  def new({ 0, nil } = self) do
    %T{tree: self}
  end

  def new(enum) when is_list(enum) do
    %T{tree: enum |> :orddict.from_list |> :gb_trees.from_orddict  }
  end
  def new(enum) when not is_list(enum), do: new( enum |> Enum.to_list )

  def has_key?(%T{tree: self}, key), do: :gb_trees.is_defined( key, self )

  def fetch(%T{tree: self}, key) do
    case :gb_trees.lookup(key, self) do
      {:value, value } -> {:ok, value}
      :none -> {:error, nil}
    end
  end

  def put(%T{tree: self}, key, value) do
    %T{tree: :gb_trees.enter(key, value, self) }
  end

  def delete(%T{tree: self}, key) do
    %T{tree: :gb_trees.delete_any(key, self)}
  end

  def keys(%T{tree: self}), do: :gb_trees.keys(self)

  def values(%T{tree: self}), do: :gb_trees.values(self)

  def size(%T{tree: self}), do: :gb_trees.size(self)

  def to_list(%T{tree: self}), do: :gb_trees.to_list(self)

  def member?(%T{tree: self}, key, value) do
    case :gb_trees.lookup(key, self) do
      {:value, ^value} -> true
      _ -> false
    end
  end

  def last(%T{tree: self}) when self == { 0, nil } do
    {:error, nil}
  end
  def last(%T{tree: self}) do
    {:ok, :gb_trees.largest(self)}
  end

  def first(%T{tree: self}) when self == { 0, nil } do
    {:error, nil}
  end
  def first(%T{tree: self}) do
    {:ok, :gb_trees.smallest(self)}
  end

  def traverse(%T{tree: self}, fun, acc, rev \\ false) when is_function(fun,3) do
    {_sz, tr} = self
    if rev, do: traverse_1(acc, tr, fun), else: traverse_1_rev(acc, tr, fun)
  end

  defp traverse_1(acc, nil, _fun), do: acc
  defp traverse_1({:stop, _} = acc, _, _fun), do: acc
  defp traverse_1(acc, {key, value, smaller, bigger}, fun) do
    traverse_1(acc, smaller, fun)
    |> fun.(key, value)
    |> traverse_1(bigger, fun)
  end

  defp traverse_1_rev(acc, nil, _fun), do: acc
  defp traverse_1_rev({:stop, _} = acc, _, _fun), do: acc
  defp traverse_1_rev(acc, {key, value, smaller, bigger}, fun) do
    traverse_1_rev(acc, bigger, fun)
    |> fun.(key, value)
    |> traverse_1_rev(smaller, fun)
  end

  def traverse_while(%T{tree: self}, fun, acc, pred, rev \\ false) when is_function(fun,3) and is_function(pred,3) do
    {_sz, tr} = self
    cfun = fn
      {:cont, lacc}, k, v ->
         if pred.(lacc, k, v), do: {:cont, fun.(lacc, k, v)}, else: {:stop, lacc}
      {:stop, _lacc} = x, _,_ -> x
    end
    {_, r} = (
      if rev, do: traverse_1_rev({:cont, acc}, tr, cfun), else: traverse_1({:cont, acc}, tr, cfun)
    )
    r
  end

  @doc "Implementation analog to :gb_trees.update/3, but with update-function instead of new value"
  def update_using(%T{tree: self} = tree, key, f) when is_function(f,1) do
    if :gb_trees.is_defined( key, self ) do
        {size, et} = self
        nt = update_1(key, f, et)
        %T{tree: {size, nt}}
    else
      tree
    end
  end

  defp  update_1(key, f, {key1, v, smaller, bigger}) do
    cond do
      key < key1 -> {key1, v, update_1(key, f, smaller), bigger}
      key > key1 -> {key1, v, smaller, update_1(key, f, bigger)}
      true -> {key, f.(v), smaller, bigger}
    end
  end

  def le_path(%T{tree: self}, criteria) do
    {size, et} = self
    if size == 0, do: [], else: le_path_1(et, criteria, [])
  end

#  defp le_path_1({k, _, _, _} = node, c, l) when k == c, do: [node | l]

  defp le_path_1({k, _, s, _} = node, c, l) when c < k, do: le_path_1(s, c, [node | l])

  defp le_path_1({k, _, _, b} = node, c, l) when c > k, do: le_path_1(b, c, [node | l])

  defp le_path_1(node, _, l), do: :lists.reverse( [node | l] )

  @doc "Implementation analog to :gb_trees.iterator/1
  https://github.com/erlang/otp/blob/master/lib/stdlib/src/gb_trees.erl"
  def iterator(%T{tree: {_size, tr}}), do: iterator_1(tr)

  defp iterator_1(tr), do: iterator(tr, [])

  defp iterator({_, _, nil, _} = tr, as), do: [tr | as]
  defp iterator({_, _, l, _} = tr, as), do: iterator(l, [tr | as])
  defp iterator(nil, as), do: as

  @doc "Implementation analog to gb_trees.iterator_from/2, `start` is second argument!"
  def iterator_from(%T{tree: {_size, tr}}, start), do: iterator_1_from(start, tr)

  defp iterator_1_from(s, t), do: iterator_from(s, t, [])

  defp iterator_from(s, {k, _, _, t}, as) when k < s do
    iterator_from(s, t, as)
  end
  defp iterator_from(_, {_, _, nil, _} = t, as), do: [t | as]
  defp iterator_from(s, {_, _, l, _} = t, as), do: iterator_from(s, l, [t | as])
  defp iterator_from(_, nil, as), do: as

  @doc "Implementation analog to :gb_trees.next/1"
  def next([{x, v, _, t} | as]), do: {x, v, iterator(t, as)}
  def next([]), do: :none

  @doc ""
  def iterator_rev(%T{tree: {_size, tr}}), do: iterator_rev_1(tr)

  defp iterator_rev_1(tr), do: iterator_rev(tr, [])

  defp iterator_rev({_, _, _, nil} = tr, as), do: [tr | as]
  defp iterator_rev({_, _, _, b} = tr, as), do: iterator_rev(b, [tr | as])
  defp iterator_rev(nil, as), do: as

  @doc ""
  def iterator_from_rev(%T{tree: {_size, tr}}, start), do: iterator_1_from_rev(start, tr)

  defp iterator_1_from_rev(s, t), do: iterator_from_rev(s, t, [])

  defp iterator_from_rev(s, {k, _, t, _}, as) when k > s do
    iterator_from_rev(s, t, as)
  end
  defp iterator_from_rev(_, {_, _, _, nil} = t, as), do: [t | as]
  defp iterator_from_rev(s, {_, _, _, b} = t, as), do: iterator_from_rev(s, b, [t | as])
  defp iterator_from_rev(_, nil, as), do: as

  def next_rev([{x, v, t, _} | as]), do: {x, v, iterator_rev(t, as)}
  def next_rev([]), do: :none

# resource(start_fun, next_fun, after_fun)
# resource(
#   (() -> acc()),
#   (acc() -> {[element()], acc()} | {:halt, acc()}),
#   (acc() -> term())
# ) :: Enumerable.t()

  def stream(%T{tree: _self} = tt, start \\ nil) do
    Stream.resource(
      #fn -> :gb_trees.iterator(self) end,
      cond do
        start == nil -> fn -> iterator(tt) ## test own iterator vs #:gb_trees.iterator(self)
            end
        true -> fn -> iterator_from(tt, start) end  #:gb_trees.iterator_from(start, self)
      end ,
      fn iterator ->
        # next(Iter1) -> none | {Key, Value, Iter2}
        case next(iterator) do #:gb_trees.next(iterator) do
          :none -> {:halt, iterator}
          {k, v, iter2} ->
            {[{k, v}], iter2}
          #x -> throw(IO.inspect(x))
        end
      end,
      fn _ -> 1 end
    )
  end

  def stream_rev(%T{tree: _self} = tt, start \\ nil) do
    Stream.resource(
      cond do
        start == nil -> fn -> iterator_rev(tt)
            end
        true -> fn -> iterator_from_rev(tt, start) end
      end ,
      fn iterator ->
        case next_rev(iterator) do
          :none -> {:halt, iterator}
          {k, v, iter2} ->
            {[{k, v}], iter2}
        end
      end,
      fn _ -> 1 end
    )
  end

  defimpl Enumerable, for: Edata.Btree do
    def reduce(%T{tree: self}, acc, fun) do
      do_reduce(:gb_trees.iterator(self) |> :gb_trees.next, acc, fun)
    end

    def slice(tree) do
      {:ok, Edata.Btree.size(tree) ,fn start, length -> slice(tree, start, length) end}
    end

    def slice(tree, start, nrelems) when start >= 0 and nrelems >=1 do
        tree |> Edata.Btree.stream |> Enum.drop(start) |> Enum.take(nrelems)
    end

    def member?(tree, {key, value}), do: {:ok, Edata.Btree.member?(tree, key, value)}
    def count(tree), do: {:ok, Edata.Btree.size(tree)}

    defp do_reduce(_,     {:halt, acc}, _fun),   do: {:halted, acc}
    defp do_reduce(iterator,  {:suspend, acc}, fun), do: {:suspended, acc, &do_reduce(iterator, &1, fun)}
    defp do_reduce(:none,    {:cont, acc}, _fun),   do: {:done, acc}
    defp do_reduce({k, v, iter2}, {:cont, acc}, fun) do
      do_reduce(:gb_trees.next(iter2), fun.({k, v}, acc), fun)
    end
  end

  defimpl Collectable, for: Edata.Btree do
    def into(tree) do
      collector_fun = fn
        tr, {:cont, {key, value}} -> Edata.Btree.put(tr, key, value)
        tr, :done -> tr
        _tr, :halt -> :ok
      end

      {tree, collector_fun}
    end
  end

end # module
