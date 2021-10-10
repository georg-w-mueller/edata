defmodule Edata.V8 do
  alias __MODULE__, as: V

  @size 8
  defstruct [  :_0, :_1, :_2, :_3, :_4, :_5, :_6, :_7 ]

  def new(), do: %V{}
  def max_index(), do: @size - 1
  def size(), do: @size

  def get(%V{_0: r},  0), do: r
  def get(%V{_1: r},  1), do: r
  def get(%V{_2: r},  2), do: r
  def get(%V{_3: r},  3), do: r
  def get(%V{_4: r},  4), do: r
  def get(%V{_5: r},  5), do: r
  def get(%V{_6: r},  6), do: r
  def get(%V{_7: r},  7), do: r
  def get(%V{} = this, n) when is_integer(n), do: raise "Invalid 'get' for structure: #{inspect(this)}"
  def get(nil, n) when is_integer(n) and n>=0 and n<@size, do: nil

  def set(%V{} = this,  0, value), do: %V{ this | _0: value}
  def set(%V{} = this,  1, value), do: %V{ this | _1: value}
  def set(%V{} = this,  2, value), do: %V{ this | _2: value}
  def set(%V{} = this,  3, value), do: %V{ this | _3: value}
  def set(%V{} = this,  4, value), do: %V{ this | _4: value}
  def set(%V{} = this,  5, value), do: %V{ this | _5: value}
  def set(%V{} = this,  6, value), do: %V{ this | _6: value}
  def set(%V{} = this,  7, value), do: %V{ this | _7: value}
  def set(%V{} = this,  n, _value) when is_integer(n), do: raise "Invalid 'set #{inspect (n)}' for structure: #{inspect(this)}"
  def set(nil,  n, value), do: new() |> set(n, value)

  def update(%V{} = this, n, f) when is_integer(n) and is_function(f) do
    set(this, n, f.(get(this, n)))
  end

  defimpl Enumerable, for: Edata.V8 do

    def slice(%V{} = this) do
      {:ok, Edata.V8.size(),fn start, length -> Enum.drop(this, start) |> Enum.take(length) end}
    end
    def member?(vc, value) do
      {:ok, (0..Edata.V8.max_index()) |> Enum.any?(fn i -> value == Edata.V8.get(vc, i) end)
      }
    end
    def count(%V{}), do: {:ok, Edata.V8.size()}
    def reduce(%V{} = this, acc, fun) do
      reduce({this, 0, Edata.V8.size()}, acc, fun)
    end

    def reduce(_,     {:halt, acc}, _fun),   do: {:halted, acc}
    def reduce(iterator,  {:suspend, acc}, fun), do: {:suspended, acc, &reduce(iterator, &1, fun)}
    def reduce({_this, fin, fin}, {:cont, acc}, _fun),   do: {:done, acc}
    def reduce({ this, cur, fin}, {:cont, acc}, fun) do
      reduce({this, cur+1, fin}, fun.( Edata.V8.get(this, cur) , acc), fun)
    end

  end # Enumerable
end
