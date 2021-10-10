defmodule Edata.StreamSplit do
  alias __MODULE__, as: SS
  @doc """
  https://github.com/tallakt/stream_split/blob/master/lib/stream_split.ex
  This function is a combination of `Enum.take/2` and `Enum.drop/2` returning
  first `n` dropped elements and the rest of the enum as a stream.

  The important difference is that the enumerable is only iterated once, and
  only for the required `n` items. The rest of the enumerable may be iterated
  lazily later from the returned stream.

  ## Examples
      iex> {head, tail} = take_and_drop(Stream.cycle(1..3), 4)
      iex> head
      [1, 2, 3, 1]
      iex> Enum.take(tail, 7)
      [2, 3, 1, 2, 3, 1, 2]
  """
  @spec take_and_drop(Enumerable.t, pos_integer) :: {List.t, Enumerable.t}
  def take_and_drop(enum, n) when n > 0 do
    case Enumerable.reduce(enum, {:cont, {n, []}}, &reducer_helper/2) do
      {:done, {_, list}} ->
        {:lists.reverse(list), []}
      {:suspended, {_, list}, cont} ->
        {:lists.reverse(list), continuation_to_stream(cont)}
      {:halted, _} -> {[],[]}  # gms
    end
  end
  def take_and_drop(enum, 0) do
    {[], enum}
  end

  defp reducer_helper(item, :tail) do
    {:suspend, item}
  end

  defp reducer_helper(item, {c, list}) when c > 1 do
    {:cont, {c - 1, [item | list]}}
  end

  defp reducer_helper(item, {_, list}) do
    {:suspend, {0, [item | list]}}
  end

  def continuation_to_stream(cont) do
    wrapped =
      fn {_, _, acc_cont} ->
        case acc_cont.({:cont, :tail}) do
          acc = {:suspended, item, _cont} ->
            {[item], acc}
          {:done, acc} ->
            {:halt, acc}
          {:halted, :tail} -> {:halt, []} # gms
        end
      end
    cleanup =
      fn
        {:suspended, _, acc_cont} ->
          acc_cont.({:halt, nil})
        _ ->
          nil
      end
    Stream.resource(fn -> {:suspended, nil, cont} end, wrapped, cleanup)
  end

  @doc """
  This function looks at the first `n` items in a stream. The remainder of the
  enumerable is returned as a stream that may be lazily enumerated at a later
  time.

  You may think of this function as popping `n` items of the enumerable, then
  pushing them back after making a copy.

  Use this function with a stream to peek at items, but not iterate a stream
  with side effects more than once.

  ## Examples
      iex> {head, new_enum} = peek(Stream.cycle(1..3), 4)
      iex> head
      [1, 2, 3, 1]
      iex> Enum.take(new_enum, 7)
      [1, 2, 3, 1, 2, 3, 1]
  """
  @spec peek(Enumerable.t, pos_integer) :: {List.t, Enumerable.t}
  def peek(enum, n) when n >= 0 do
    {h, t} = take_and_drop enum, n
    {h, Stream.concat(h, t)}
  end

  @doc """
  This function may be seen as splitting head and tail for a `List`, but for
  enumerables.

  It is implemented on top of `take_and_drop/2`

  ## Examples
      iex> {head, tail} = pop(Stream.cycle(1..3))
      iex> head
      1
      iex> Enum.take(tail, 7)
      [2, 3, 1, 2, 3, 1, 2]
  """
  @spec pop(Enumerable.t) :: {any, Enumerable.t}
  def pop(enum) do
    {[h], rest} = take_and_drop enum, 1
    {h, rest}
  end

  def loop(n, l) do
    receive do
      {:store, element, pos} = content ->
        IO.inspect(content)
        case n == pos do
          true -> loop(n + 1, [element | l])
          _ -> raise "Expected #{n}, got #{pos}"
        end
      {:yield, from, rem} ->
        IO.inspect([:reply, {n, l, rem}])
        send from, {n, l, rem}
      :stop -> nil
      # after 1000 *  ..
    end
  end

  def init_loop(n), do: spawn fn -> loop(n, []) end

  def store(proc, element, pos), do: send proc, {:store, element, pos}

  def init_yield(proc, rem), do: send proc, {:yield, self(), rem}

  def yield() do
    receive do
      x ->
        IO.inspect([:got, x])
        x
    after 1000 -> :noresponse
    end
  end

# :erlang.unique_integer([:monotonic])
# Process.register(pid, atom)

  defstruct [:p1, :p2, :ff2, :inity]

  def apply({p1, p2} = this, f) when is_function(f,1) do
    lenp1 = length(p1)
    proc = SS.init_loop(lenp1)
    arg = SS.new(p1, p2, &SS.store(proc, &1, &2), &SS.init_yield(proc, &1))
    r = f.(arg)
    contf = #fn ->
      case SS.yield() do
        {n, fromp2, np2} ->
          if n <= lenp1, do: this, else: {p1 ++ :lists.reverse(fromp2), np2}
        :noresponse -> nil
        x -> raise "Cannot handle #{x}"
      end
      send proc, :stop  # anyway
    #end
    {r, contf}
  end

  def new(p1, p2, ff2, inity), do: %SS{p1: p1, p2: p2, ff2: ff2, inity: inity}

  defimpl Enumerable, for: Edata.StreamSplit do
    def count(_ps), do: {:error, __MODULE__}
    def member?(_ps, _value), do: {:error, __MODULE__}
    def slice(_ps), do: {:error, __MODULE__}

    def reduce(%SS{p1: p1, p2: p2, ff2: ff2, inity: inity}, acc, fun) do
      # lenp1 = length(p1)
      # proc = SS.init_loop(lenp1)
      # ff2 = &SS.store(proc, &1, &2)
      # inity = &SS.init_yield(proc, &1)
      iterator = {0, p1, p2, ff2, inity}
      reduce(iterator, acc, fun)
    end

    def reduce({_n, _p1, p2, _ff2, inity}, {:halt, acc}, _fun) do
      inity.(p2)
      {:halted, acc}
    end

    def reduce({_n, _p1, _p2, _ff2, _inity} = iterator, {:suspend, acc}, fun), do: {:suspended, acc, &reduce(iterator, &1, fun)}

    def reduce({n, [h | t], p2, ff2, inity} = _iterator, {:cont, acc}, fun)   do
      reduce({n+1, t, p2, ff2, inity}, fun.(h, acc), fun)
    end

    def reduce({n, [], p2, ff2, inity} = _iterator, {:cont, acc}, fun)   do
      case SS.take_and_drop(p2, 1) do
        {[], _} ->
          inity.([])
          {:done, acc}
        {[element], rest} ->
          ff2.(element, n)
          reduce({n+1, [], rest, ff2, inity}, fun.(element, acc), fun)
      end
    end
  end # defimpl
end
