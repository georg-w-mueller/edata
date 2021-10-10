defmodule Edata.Olist do
  @moduledoc """
  Annotated {key, value}-List with ordered behavior
  """
  alias __MODULE__, as: O

  @key_pos 0  # Elixir-tuple first index = 0
  @full_cnt 9
  @r_size 3
  @default nil

  defstruct min_key: nil, max_key: nil, data: [], ascending: true, size: 0 # , full_cnt: @full_cnt, r_size: @r_size

  def new(ascending \\ true) when is_boolean(ascending) do
    %O{ ascending: ascending}
  end
  def new_single({k, _} = tuple, ascending \\ true) when is_tuple(tuple) and is_boolean(ascending) do
   %O{ new(ascending) | data: [tuple], min_key: k, max_key: k, size: 1}
  end

  def new_from([], _min, _max, ascending, _len), do: new(ascending)
  def new_from(l, min, max, ascending, len) when is_list(l) do
    %O{ new(ascending) | data: l, min_key: min, max_key: max, size: len}
  end

  def full?(%O{size: s}, max \\ @full_cnt) do
    s >= max
  end

  defp a_or_b(asc, a, b) when is_boolean(asc) and is_function(a, 0) and is_function(b,0) do
    if asc, do: a, else: b
  end

  def keymember?(%O{min_key: min, max_key: max, data: d}, key) when key in min..max do
    List.keymember?(d, key, @key_pos)
  end
  def keymember?(_, _), do: false

  def keyfind(%O{min_key: min, max_key: max, data: d}, key) when key in min..max do
    List.keyfind(d, key, @key_pos, @default)
  end
  def keyfind(_, _), do: @default

  def keystore(%O{data: [], ascending: asc}, {_,_} = tuple), do: new_single(tuple, asc)

  def keystore(%O{min_key: min, data: d, ascending: asc, size: size}=self, {key, _value}=tuple) when key < min do
    action = a_or_b(asc, fn -> [ tuple | d ] end, fn -> d ++ [tuple] end)
    %O{self | data: action.(),
              min_key: key, size: size + 1 }
  end

  def keystore(%O{max_key: max, data: d, ascending: asc, size: size}=self, {key, _value}=tuple) when key > max do
    action = a_or_b(asc, fn -> d ++ [tuple] end, fn -> [ tuple | d ] end)
    %O{self | data:  action.(),
              max_key: key, size: size + 1 }
  end

  def keystore(%O{min_key: min, max_key: max, data: d, size: size}=self, {key, _value}=tuple) do #when key in min..max do
    {nd, ns} = skeystore(self.ascending, d, key, tuple, size)
    %O{self | data: nd, size: ns,
              min_key: :erlang.min(min, key), max_key: :erlang.max(max, key) #, ascending: false
      }
  end

  # keystore(K, N, L, New) when is_integer(N), N > 0, is_tuple(New) ->
  #   keystore2(K, N, L, New).

  # keystore2(Key, N, [H|T], New) when element(N, H) == Key ->
  #     [New|T];
  # keystore2(Key, N, [H|T], New) ->
  #     [H|keystore2(Key, N, T, New)];
  # keystore2(_Key, _N, [], New) ->
  # [New].

  def skeystore(_,      [], _key, tuple, size), do: { [tuple], size+1 } # append
  def skeystore(_,      [{k, _} | t], key, tuple, size) when k == key, do: { [tuple | t], size }  # substitute
  def skeystore(true,   [{k, _} = ref | t], key, tuple, size) when k > key, do: {[tuple | [ref | t]], size+1}  # insert asc
  def skeystore(false,  [{k, _} = ref | t], key, tuple, size) when k < key, do: {[tuple | [ref | t]], size+1}  # insert desc
  def skeystore(asc,    [ref | t], key, tuple, size) do
    {nd, ns} = skeystore(asc, t, key, tuple, size)
    { [ref | nd], ns }
  end

  # keytake(Key, N, L) when is_integer(N), N > 0 ->
  #   keytake(Key, N, L, []).

  # keytake(Key, N, [H|T], L) when element(N, H) == Key ->
  #     {value, H, lists:reverse(L, T)};
  # keytake(Key, N, [H|T], L) ->
  #     keytake(Key, N, T, [H|L]);
  # keytake(_K, _N, [], _L) -> false

  def skeytake(_, [], _key, _hds), do: nil
  def skeytake(asc, [{k, _} | _], key, _hds) when (asc and k > key) or (not asc and k < key), do: nil
  def skeytake(_, [{k, _}=taken | tail], key, hds) when k == key, do: {taken, :lists.reverse(hds,tail)}
  def skeytake(asc, [hd | tail], key, hds), do: skeytake(asc, tail, key, [hd | hds])

  def keytake(%O{min_key: min, max_key: max, data: d, ascending: asc, size: size}=self, key) when key in min..max do
    case skeytake(asc, d, key, []) do #List.keytake(d, key, @key_pos) do
      nil -> {@default, self}
      {taken, rest} -> case rest do
        [] -> {taken, new(asc)}
        [{k, _} | tail] ->
          if key == min or key == max do
            {nmi, nma} = minmaxkeys(k, k, tail)
            IO.puts (inspect {nmi, nma})
            {taken, %O{self | data: rest, min_key: nmi, max_key: nma, size: size - 1}}
          else
            {taken, %O{self | data: rest, size: size - 1}}
          end
        end #case rest
    end #case List.take
  end

  def keytake(self, _), do: {@default, self}

  defp minmaxkeys(kmin, kmax, []), do: {kmin, kmax}
  defp minmaxkeys(kmin, kmax, [{n,_} | tail]) do
    minmaxkeys(:erlang.min(kmin, n), :erlang.max(kmax, n), tail)
  end

  def extract_while( %O{min_key: min, max_key: max, data: d, ascending: asc, size: size}=self, fun) when is_function(fun, 2) do
    case d do
      [] -> {self, self}  # no element   {extracted, rest}
      [{k, v}] -> if fun.(k, v) do        # single element match
          {self, new(asc)}
        else
          {new(asc), self} #
        end
      [{k, _v} | _t] -> keysf = if asc do
            fn current, recent -> {min, recent, current, max, true} end # finding, rest
          else
            fn current, recent -> {recent, max, min, current, false} end
          end
          extract_while_1(self, keysf, k, d, [], fun, 0, size) # self, keys, data, heads, fun
    end # case d
  end # extraxt_while_1

  defp extract_while_1(self, _keysf, _recent, [], _heads, _fun, _, _), do: {self, new(self.ascending)}
  defp extract_while_1(self,  keysf,  recent, [{k, v} = hd | t] = d, hds, fun, el, rl) do
    case fun.(k, v) do
      true -> extract_while_1(self, keysf, k, t, [hd | hds], fun, el+1, rl-1 )
      false -> {emin, emax, rmin, rmax, rev} = keysf.(k, recent)
        {  new_from(:lists.reverse(hds), emin, emax, rev, el),
           new_from(d, rmin, rmax, rev, rl)
        }
    end
  end

  def ascending(%O{ascending: true} = self), do: self
  def ascending(%O{data: d} = self), do: %O{self | data: List.keysort(d, @key_pos), ascending: true}

  defimpl Collectable, for: Edata.Olist do

    def into(olist) do
      collector_fun = fn
        ol, {:cont, t} -> Edata.Olist.keystore(ol, t)
        ol, :done -> ol
        _ol, :halt -> :ok
      end

      {olist, collector_fun}
    end

  end # Collectable

  defimpl Enumerable, for: Edata.Olist do

    def slice(%O{data: d, size: size}) do
      {:ok, size ,fn start, length -> Enum.slice(d, start, length) end}
    end
    def member?(ol, {key, value}) do
      {:ok, case Edata.Olist.keyfind(ol, key) do
              {^key, ^value} -> true
              _ -> false
            end
      }
    end
    def count(%O{size: size}), do: {:ok, size}
    def reduce(%O{data: d}, acc, fun) do
      reduce(d, acc, fun)
    end

    def reduce(_,     {:halt, acc}, _fun),   do: {:halted, acc}
    def reduce(iterator,  {:suspend, acc}, fun), do: {:suspended, acc, &reduce(iterator, &1, fun)}
    def reduce([],    {:cont, acc}, _fun),   do: {:done, acc}
    def reduce([h|t], {:cont, acc}, fun), do: reduce(t, fun.(h, acc), fun)

  end # Enumerable
end # module
