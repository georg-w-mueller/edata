defmodule Edata.Cstream do
  @moduledoc """
  Re-usable stream
  """

  alias __MODULE__, as: CS

  defstruct [:base, :proc, :queryf, :putf]

  def new(enum) do
    proc = start()
    queryf = fn -> query(proc) end
    putf = fn e -> put(proc, e) end
    %CS{base: enum, proc: proc, queryf: queryf, putf: putf}
  end

  def stop(%CS{proc: proc}), do: send proc, :stop

  def start do
    spawn(fn -> loop({0, []}) end)
  end

  defp loop({size, l} = content) do
    receive do
      {:get, caller} ->
        send caller, {size, :lists.reverse(l)}
        loop(content)
      {:put, element} ->
        loop({size + 1, [element | l]})
      :stop -> IO.puts("#{inspect(self())} Stopped"); nil
    end
  end

  def put(proc, element) when is_pid(proc) do
    send proc, {:put, element}
    element
  end
  def put(%CS{proc: proc}, element), do: put(proc, element)

  def query(proc) when is_pid(proc) do
    send proc, {:get, self()}
    receive do
      {_size, _list} = content -> content
    after
      100 -> :noresponse
    end
  end
  def query(%CS{proc: proc}), do: query proc

  defimpl Enumerable, for: Edata.Cstream do
    def count(_cs), do: {:error, __MODULE__}
    def member?(_cs, _value), do: {:error, __MODULE__}
    def slice(_lazy), do: {:error, __MODULE__}

    def reduce(%CS{base: enum, proc: proc, queryf: queryf, putf: putf} = _cs, acc, fun) do
      case queryf.() do
        :noresponse ->
          raise "Timeout in reduce #{inspect(proc)}, alive: #{inspect(Process.alive?(proc))}"
        {0, _list} ->
          enum |> Stream.map(fn e -> putf.(e) end)
        {size, list} ->
          #IO.inspect(size)
          Stream.concat(list,
            enum |> Stream.drop(size) |> Stream.each(fn e -> putf.(e) end)
          )
      end # case
      |> Enumerable.reduce(acc, fun)
    end

  end # defimpl Enumerable
end # module
