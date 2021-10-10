defmodule Edata.Pstream do
  @moduledoc """
  Re-usable stream, stream is kept in support process
  """

  alias __MODULE__, as: PS
  alias Edata.StreamSplit, as: SS

  defstruct [:base, :proc, :queryf, :nextf, :autoreset, :poszerof ] #, :resetf

  def new(enum, autoreset \\ true), do: new_(enum, autoreset)

  def new_([], autoreset) do
    proc = nil
    queryf = fn -> {true, 0, []}  end
    #putf = fn e -> put(proc, e) end
    nextf = fn -> {:eof, 0} end
    poszerof = fn -> nil end
    %PS{base: [], proc: proc, queryf: queryf, nextf: nextf,
      autoreset: autoreset, poszerof: poszerof}
  end

  def new_(enum, autoreset) do
    proc = start(enum, autoreset)
    queryf = fn -> query(proc) end
    #putf = fn e -> put(proc, e) end
    nextf = fn -> next(proc) end
    poszerof = fn -> poszero(proc) end
    %PS{base: enum, proc: proc, queryf: queryf, nextf: nextf,
      autoreset: autoreset, poszerof: poszerof}
  end

  def stop(%PS{proc: nil}), do: nil
  def stop(%PS{proc: proc}), do: send proc, :stop

  def start(enum, reset) do
    spawn(fn -> loop({0, [], enum, reset, nil, 0}) end)  ## base_fin == nil, no final result
  end

  defp loop({index, l, remainder, reset, base_fin, cnt} = content) do
    receive do
      {:next, caller} ->
        case trynext(remainder) do
          {:ok, h, t} ->
            send caller, {:ok, h, index}
            ncnt = (base_fin && cnt) || (index + 1)
            loop({index + 1, [h | l], t, reset, base_fin, ncnt})
          {:eof, _, []} ->
            send caller, {:eof, index}
            case reset do
              true ->
                nl = base_fin || :lists.reverse(l)
                loop({0, [], nl, reset, nl, cnt})
              false -> loop(content)
            end
        end
      {:poszero, _caller} -> (IO.puts("Possing zero")
        case {base_fin, index} do
          {_, 0} -> loop(content)
          {nil, _} -> loop({0, [], Stream.concat(:lists.reverse(l), remainder), reset, base_fin, cnt})
          _ -> loop({0, [], base_fin, reset, base_fin, cnt})
        end)

      {:query, caller} -> (
        case base_fin do
          nil  -> send caller, {false, cnt, Stream.concat(:lists.reverse(l), remainder)}
          _  -> send caller, {true, cnt, base_fin}
        end
        loop(content)
      )

      {:put, element} -> loop({index + 1, [element | l], remainder, reset, base_fin, cnt})
      :stop -> IO.puts("#{inspect(self())} Stopped"); nil
    end
  end

  def trynext([]), do: {:eof, nil, []}
  def trynext([h | t]), do: {:ok, h, t}
  def trynext(enum) do
    case SS.take_and_drop(enum, 1) do
      {[h], t} -> {:ok, h, t}
      {[], _} -> {:eof, nil, []}
    end
  end

  def poszero(proc) when is_pid(proc), do:  send proc, {:poszero, self()}
  def poszero(%PS{poszerof: poszerof}), do: poszerof.()

  def put(%PS{proc: proc}, element), do: put(proc, element)
  def put(proc, element) when is_pid(proc) do
    send proc, {:put, element}
    element
  end
  def put(%PS{proc: proc}, element), do: put(proc, element)

  def next(proc) when is_pid(proc) do
    send proc, {:next, self()}
    receive do
      x -> x
    after
      100 -> :noresponse
    end
  end
  def next(%PS{nextf: nextf}), do: nextf.()

  def query(proc) when is_pid(proc) do
    send proc, {:query, self()}
    receive do
      {_index, _list, _base_fin} = content -> content
    after
      100 -> :noresponse
    end
  end
  def query(%PS{queryf: queryf}), do: queryf.()

  defimpl Enumerable, for: Edata.Pstream do
    def count(_ps), do: {:error, __MODULE__}
    def member?(_ps, _value), do: {:error, __MODULE__}
    def slice(_ps), do: {:error, __MODULE__}

    def reduce(%PS{nextf: nextf, poszerof: poszerof, proc: proc}, acc, fun) do
      iterator = {0, nextf, poszerof, proc}
      reduce(iterator, acc, fun)
    end

    def reduce({_n, _nextf, poszerof, _proc}, {:halt, acc}, _fun) do
      poszerof.()
      {:halted, acc}
    end

    def reduce({n, nextf, poszerof, proc} = _iterator, {:cont, acc}, fun)   do
      case nextf.() do
        :noresponse -> raise "Timeout in reduce #{inspect(proc)}, alive: #{inspect(Process.alive?(proc))}"
        {:eof, index} ->
          case n == index do
            true -> {:done, acc}
            _ -> raise "Unexpected index for EOF, expected #{n}, got #{index}"
          end
        {:ok, element, index} ->
          #IO.inspect({element, index})
          case n == index do
            true -> reduce({n+1, nextf, poszerof, proc}, fun.(element, acc), fun)
            _ -> raise "Unexpected index from nextf, expected #{n}, got #{index}"
          end
      end
    end

  end # defimpl Enumerable
end # module
