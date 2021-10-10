defmodule Edata.StreamTrial do
  alias __MODULE__, as: ST

  def on_step(lst, n, addr, id, skip \\ 0) do
    fn :each ->
      fn element ->
        on_step( (if skip <= n, do: [element | lst], else: lst), n+1, addr, id, skip)
      end
       :yield ->
        fn rest ->
          on_yield(:lists.reverse(lst), rest, n, addr, id)
        end
    end
  end

  def on_yield(lst, rest, n, addr, id) do
    send addr, {:nread, id, n, lst, rest}
  end

  def from_inbox() do
    # case started() do
    #   nil -> nil
    #   id -> case get_nread(id) do
    #     nil -> nil
    #     {_n, _lst, _rest} = res -> cleanup(id, res)
    #   end
    # end
    id = started()
    nread = id && get_nread(id)
    nread && cleanup(id, nread)
  end

  def started() do
    receive do
      {:started, id} -> id
    after 0 -> nil
    end
  end

  def get_nread(id) do
    receive do
      {:nread, ^id, n, lst, rest} -> {n, lst, rest}
    after 0 -> nil
    end
  end

  def cleanup(id, res) do
    receive do
      {:finished, ^id} -> {:fin, res}
    after 0 -> {:nofin, res}
    end
  end

  def trans(enum, skip \\ 0) do
    step = fn val, _acc -> {:suspend, val} end
    next = &Enumerable.reduce(enum, &1, step)
    addr = self()
    id = :erlang.unique_integer([:monotonic]) # or: :erlang.make_ref
    onf = on_step([], 0, addr, id, skip)
    fn f1, f2 ->
      send addr, {:started, id}
      r = trans_(onf, next, f1, f2)
      send addr, {:finished, id}
      r
    end
  end

  # stream suspended
  defp trans_(onf, next, {:suspend, acc}, fun) do
    IO.inspect([onf, :susp])
    {:suspended, acc, &trans_(onf, next, &1, fun)}
  end

  # stream halted
  defp trans_(onf, next, {:halt, acc}, _fun) do
    onf.(:yield).( Edata.StreamSplit.continuation_to_stream next )
    {:halted, acc}
  end

  # ~loop
  defp trans_(onf, next, {:cont, acc}, fun) do
    #IO.inspect([n, :loop, acc])
    case next.({:cont, onf}) do
      {:suspended, val, next} ->
        IO.inspect([:value, val])
        trans_(onf.(:each).(val), next, fun.(val, acc), fun)
      {:done, _} = _r ->
        #IO.inspect([:done_, r])
        onf.(:yield).([])
        {:halted, acc}
    end
  end

  def distinct_crafted(enum) do
    step = fn val, _acc -> {:suspend, val} end
    next = &Enumerable.reduce(enum, &1, step)
    &distinct_crafted_(MapSet.new, next, &1, &2)
  end

  defp distinct_crafted_(coll, next, {:suspend, acc}, fun) do
    {:suspended, acc, &distinct_crafted_(coll, next, &1, fun)}
  end

  defp distinct_crafted_(_coll, _next, {:halt, acc}, _fun) do
    {:halted, acc}
  end

  defp distinct_crafted_(coll, next, {:cont, acc}, fun) do
    case next.({:cont, coll}) do
      {:suspended, val, next} ->
        case MapSet.member?(coll, val) do
          true -> distinct_crafted_(coll, next, {:cont, acc}, fun)
          _ -> distinct_crafted_(MapSet.put(coll, val), next, fun.(val, acc), fun)
        end
      {_, _} -> {:halted, acc}
    end
  end

  def distinct(enum) do
    Stream.transform(enum, [],
    fn e, acc ->
      if Enum.any?(acc, &(&1 == e)), do: {[], acc}, else: {[e], [e | acc]}
    end)
  end

  def distinct_man(enum) do
    Stream.transform(enum, [],
    fn e, acc ->
      if any?(e, acc), do: {[], acc}, else: {[e], [e | acc]}
    end)
  end

  def distinct_mapset(enum) do
    Stream.transform(enum, MapSet.new(),
    fn e, acc ->
      if MapSet.member?(acc, e), do: {[], acc}, else: {[e], acc |> MapSet.put(e) }
    end)
  end

  def any?(_element, []), do: false
  def any?(element, [hd | tl]) do
    case element == hd do
      true -> true
      _ -> any?(element, tl)
    end
  end

  ##
  def lookahead(enum, n) do
    step = fn val, _acc -> {:suspend, val} end
    next = &Enumerable.reduce(enum, &1, step)
    &do_lookahead(n, :buffer, [], next, &1, &2)
  end

  # stream suspended
  defp do_lookahead(n, state, buf, next, {:suspend, acc}, fun) do
    {:suspended, acc, &do_lookahead(n, state, buf, next, &1, fun)}
  end

  # stream halted
  defp do_lookahead(_n, _state, _buf, _next, {:halt, acc}, _fun) do
    {:halted, acc}
  end

  # initial buffering
  defp do_lookahead(n, :buffer, buf, next, {:cont, acc}, fun) do
    case next.({:cont, []}) do
      {:suspended, val, next} ->
        new_state = if length(buf) < n, do: :buffer, else: :emit
        do_lookahead(n, new_state, buf ++ [val], next, {:cont, acc}, fun)
      {_, _} ->
        do_lookahead(n, :emit, buf, next, {:cont, acc}, fun)
    end
  end

  # emitting
  defp do_lookahead(n, :emit, [_|rest] = buf, next, {:cont, acc}, fun) do
    case next.({:cont, []}) do
      {:suspended, val, next} ->
        do_lookahead(n, :emit, rest ++ [val], next, fun.(buf, acc), fun)
      {_, _} ->
        do_lookahead(n, :emit, rest, next, fun.(buf, acc), fun)
    end
  end

  # buffer empty, halting
  defp do_lookahead(_n, :emit, [], _next, {:cont, acc}, _fun) do
    {:halted, acc}
  end
end
