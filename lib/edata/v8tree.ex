defmodule Edata.V8tree do
  alias __MODULE__, as: V
  alias Edata.V8

  require Bitwise

  defstruct [size: 0, levels: 0, node: nil, default: nil, default_fun: nil]

  # @w 8
  @shift 3  # 2^3 = 8
  # @mask 7   # 8 - 1

  def size(%V{size: s}), do: s

  defp nilmap(value) do
    case value do
      nil -> &(&1)
      _ -> fn nil -> value
              x -> x
      end # fn e ->
    end # case value
  end # nilmap

  def new(size, default \\ nil) when is_integer(size) and size>0 do
    levels = (:math.log2(size) / @shift) |> :math.ceil() |> trunc()   # integer, 1 for size <= 8, 2f <= 64, 3f <= 512
    deff = nilmap(default);
    %V{size: size, levels: levels, node: V8.new(), default: default, default_fun: deff}
  end

  def pair(n, l) when is_integer(n) and n>=0 do
    #{Bitwise.band(n, @mask), Bitwise.bsr(n, @shift)} # works fine, but distributes oddly.
    pf =  Bitwise.bsl(1, (l-1)*3) # :math.pow(8, l-1) |> trunc()
    node = div(n, pf)
    newnr = rem(n, pf)
    #IO.puts(inspect([n, l, :x, pf, node, newnr]))
    {node, newnr}
  end

  def get(%V{size: s, levels: l, node: node, default_fun: deff}, n) when is_integer(n) and n>=0 and n<s do
    (if (l <= 1) do
      V8.get(node, n)
    else
      {nnr , nn} = pair(n, l)
      get_1(V8.get(node, nnr), nn, l-1)
    end) |> deff.()
  end

  def get(%V{} = this, n), do: raise "Get-Index #{inspect(n)} out of bounds for: #{inspect(this)}"

  defp get_1(nil, _n, _l), do: nil
  defp get_1(%V8{} = this, n, l) do
    if (l <= 1) do
      V8.get(this, n)
    else
      {nnr , nn} = pair(n,l)
      get_1(V8.get(this, nnr), nn, l-1)
    end
  end

  def set(%V{size: s, levels: l, node: node} = this, n, value) when is_integer(n) and n>=0 and n<s do
    if (l <= 1) do
      %V{ this | node: V8.set(node, n, value)}
    else
      {nnr , nn} = pair(n,l)
      newelement = set_1(V8.get(node, nnr), nn, l-1, value)
      %V{ this | node: V8.set(node, nnr, newelement)}
    end
  end

  def set(%V{} = this, n, _value), do: raise "Set-Index #{inspect(n)} out of bounds for: #{inspect(this)}"

  defp set_1(nil, n, l, value) do
    if (l <= 1) do
      V8.set(V8.new(), n, value)
    else
      {nnr , nn} = pair(n,l)
      V8.set(V8.new(), nnr, set_1(nil, nn, l-1, value))
    end
  end

  defp set_1(%V8{} = this, n, l, value) do
    if (l <= 1) do
      V8.set(this, n, value)
    else
      {nnr , nn} = pair(n,l)
      V8.set(this, nnr, set_1(V8.get(this, nnr), nn, l-1, value))
    end
  end

  def update(%V{} = this, n, fun) when is_function(fun, 1) do
    set(this, n, fun.(get(this, n)))
  end

  def default_acc_fun() do
    fn
      :init, _    -> {0, []}
      :done, acc -> {_, l} = acc; :lists.reverse(l)
      value, acc  -> {i, l} = acc; {i + 1, [ {i, value} | l ]}
    end
  end

  @doc "wraps accumulator fun for usage with 'reduce_while'"
  def limit_transd(n, deffun) when is_integer(n) do
    fn rf ->
      fn
        :init, v    -> rf.(:init, v)
        :done, acc  -> rf.(:done, acc)
        value, acc  -> {i, _l} = acc;
          if (i < n) do
            {:cont, rf.( deffun.( value ), acc)}
          else
            {:halt, acc}
          end
      end
    end
  end

  def traverse(%V{levels: l, node: node, size: s, default_fun: deffun}, fun) when is_function(fun, 2) do
    lfun = limit_transd(s, deffun).(fun)
    lfun.(:done, traverse_(node, l, lfun, lfun.(:init, nil), Edata.V8.new()))
    # fun.(:done, traverse_(node, l, fun, fun.(:init, nil), Edata.V8.new()))
  end

  def traverse_(nil, l, fun, acc, empty) do
    if (l <= 1) do
      #Enum.reduce(empty, acc, fun)
      Enum.reduce_while(empty, acc, fun)
    else
      transreduce(empty, l-1, fun, acc, empty)
    end
  end

  def traverse_(%V8{} = this, l, fun, acc, empty) do
    if (l <= 1) do
      # Enum.reduce(this, acc, fun)
      Enum.reduce_while(this, acc, fun)
    else
      transreduce(this, l-1, fun, acc, empty)
    end
  end

  defp transreduce(node, level, fun, acc, empty) do
    # (0..7) |> Enum.reduce(acc, fn i,a ->
    #   traverse_(V8.get(node, i), level - 1, fun, a, empty)
    # end)
    Enum.reduce(node, acc, fn element,a ->
      traverse_(element, level - 1, fun, a, empty)
    end)
  end

  @doc "position at index 0, 'structure' for 'next'"
  def iterator(%V{levels: l, node: node, size: s, default_fun: deffun}) do
    # template = {Edata.V8.new(), deffun, s}
    # start, max, path, template, default
    { 0, s, iterator_1(l, node, [], 0), Edata.V8.new(), deffun }
  end

  def iterator_1(_l, _node, path, 8) do
    path
  end

  def iterator_1(1, node, path, n) do
    [ {node, 1, n} | path  ]
  end

  # def iterator_1(level, nil, path, n) when level > 1 do
  #   iterator_1(level - 1, nil, [{nil, level, n} | path], 0)
  # end

  def iterator_1(level, node, path, n) when level > 1 do
    cont = V8.get(node, n)
    iterator_1(level - 1, cont, [{node, level, n} | path], 0)
  end

  def next( { s, s, _path, _template, _deffun }), do: :done
#  def next( [] ), do: :done
  def next( { c, s, [{_node,_l, 8} | path], t, d }), do: next({c, s, path, t, d})  ## current node is due (any level)
  def next( { c, s, [{ node, 1, n} | path], t, d }) do               ## continue current node
    # rn = (if node == nil, do: t, else: node)
    # { d.( V8.get(rn, n) ),              # result (defaulted)
    #       { c+1, s, [ {rn, 1, n+1} | path ], t, d} # iterator
    # }
    { d.( V8.get(node, n) ),              # result (defaulted)
          { c+1, s, [ {node, 1, n+1} | path ], t, d} # iterator
    }
  end

  def next( {c, s, [{node, level, n} | path], t, d} ) do           ## current level is not ~output~
    nit = iterator_1(level, node, path, n + 1)
    next({ c, s, nit, t, d});
  end

  def next_upd({ s, s, _path, _template, _deffun }=iterator, _updf), do: {:done, iterator}
  def next_upd({ c, s, [{_node,_l, 8} | path], t, d }, updf), do: next_upd({c, s, path, t, d}, updf)
  def next_upd({ c, s, [{ node, 1, n} | path], t, d }, updf) do
    #rn = (if node == nil, do: t, else: node)
    newvalue = updf.( d.( V8.get(node, n) ) ) #rn
    mnode = V8.set(node, n, newvalue)
    { newvalue,
          { c+1, s, [ {mnode, 1, n+1} | fixpath(mnode, path) ], t, d} # iterator
    }
  end

  def next_upd( {c, s, [{node, level, n} | path], t, d}, updf ) do
    nit = iterator_1(level, node, path, n + 1)
    next_upd({ c, s, nit, t, d}, updf);
  end

  def fixpath(_v, []), do: []
  def fixpath(v, [{node, l, n} | path]) do
    # t = (if node == nil, do: V8.new(), else: node)
    nn = V8.set(node, n, v)
    [{nn, l, n}] ++ fixpath(nn, path)
  end

  def update(%V{}=this, updf) do
    iterator = iterator(this)
    update_( next_upd(iterator, updf), updf )
    |> iterator_to_tree()
  end

  defp update_( {:done, iterator}, _updf), do: iterator
  defp update_( {_v, iterator}, updf), do: update_( next_upd(iterator, updf), updf )

  def iterator_to_tree({_current, size, path, _template, deff}) do
    # size: 0, levels: 0, node: nil, default: nil, default_fun: ni
    l = length(path)
    node = itotree(path)
    %V{ size: size, node: node, levels: l, default: deff.(nil), default_fun: deff}
  end

  defp itotree( [{node, _l, _n} ]), do: node
  defp itotree( [{nil, _ln, _n} | t ]), do: itotree(t)
  defp itotree( [{node, _ln, _n} | [ {pnode, lp, n}  | t] ]) do
    xn = (if pnode == nil, do: V8.new(), else: pnode)
    itotree( [{V8.set(xn, n, node), lp, n} | t] )
  end

  defimpl Enumerable, for: Edata.V8tree do

    def slice(%V{size: s} = this) do
      {:ok, s, fn start, length -> Enum.drop(this, start) |> Enum.take(length) end}
    end
    def member?(%V{size: s} = this, value) do
      {:ok, (0..s-1) |> Enum.any?(fn i -> value == Edata.V8tree.get(this, i) end)
      }
    end
    def count(%V{size: s}), do: {:ok, s}

    # def reduce(%V{size: s} = this, acc, fun) do
    #   reduce({this, 0, s}, acc, fun)
    # end

    # def reduce(_,     {:halt, acc}, _fun),   do: {:halted, acc}
    # def reduce(iterator,  {:suspend, acc}, fun), do: {:suspended, acc, &reduce(iterator, &1, fun)}
    # def reduce({_this, fin, fin}, {:cont, acc}, _fun),   do: {:done, acc}
    # def reduce({ this, cur, fin}, {:cont, acc}, fun) do
    #   reduce({this, cur+1, fin}, fun.( Edata.V8tree.get(this, cur) , acc), fun)
    # end
    def reduce(%V{} = this, acc, fun) do
      iterator = Edata.V8tree.iterator(this)
      reduce(Edata.V8tree.next(iterator), acc, fun)
    end

    def reduce(_,     {:halt, acc}, _fun),   do: {:halted, acc}
    def reduce(iterator,  {:suspend, acc}, fun), do: {:suspended, acc, &reduce(iterator, &1, fun)}
    def reduce(:done, {:cont, acc}, _fun),   do: {:done, acc}
    def reduce({ current, next }, {:cont, acc}, fun) do
      reduce( Edata.V8tree.next(next), fun.( current , acc), fun)
    end

  end # Enumerable

  defimpl Collectable, for: Edata.V8tree do
    def into(tree) do
      collector_fun = fn
        tr, {:cont, {key, value}} -> Edata.V8tree.set(tr, key, value)
        tr, :done -> tr
        _tr, :halt -> :ok
      end

      {tree, collector_fun}
    end
  end

end # module
