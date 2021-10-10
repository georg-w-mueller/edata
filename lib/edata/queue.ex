defmodule Edata.Queue do
  alias __MODULE__, as: Q

  defstruct  front: [], tail: [], length: 0

  def new(), do: %Q{}

  def size(%Q{length: l}), do: l

  def empty?(%Q{length: 0}), do: true
  def empty?(%Q{}), do: false

  def add(%Q{length: l, tail: t}=this, e) do
    %Q{this | length: l+1, tail: [e | t] }
  end

  def take(%Q{length: 0}=this), do: raise "Cannot take from empty queue: #{inspect(this)}"

  def take(%Q{length: l, front: [h | frontrest]}=this) do
    {h, %Q{this | length: l - 1, front: frontrest}}
  end

  def take(%Q{length: l, tail: t}) do
    [h | resttail] = :lists.reverse(t)
    {h, %Q{length: l - 1, front: resttail, tail: []}}
  end

  def member?(%Q{front: f, tail: t}, element) do
    Enum.any?(f, &(&1 == element)) or Enum.any?(t, &(&1 == element))
  end

  def dropfirst(%Q{length: 0} = this), do: this
  def dropfirst(%Q{} = this) do
    {_, r} = take(this)
    r
  end

  defimpl Collectable, for: Edata.Queue do
    def into(queue) do
      collector_fun = fn
        q, {:cont, t} -> Edata.Queue.add(q, t)
        q, :done -> q
        _q, :halt -> :ok
      end
      {queue, collector_fun}
    end
  end # Collectable

  defimpl Enumerable, for: Edata.Queue do

    def slice(%Q{front: f, tail: t, length: size}) do
      {:ok, size ,fn start, length -> Enum.slice( f ++ :lists.reverse(t), start, length) end}
    end
    def member?(q, element), do: {:ok, Edata.Queue.member?(q, element) }

    def count(%Q{length: size}), do: {:ok, size}
    def reduce(%Q{} = this, acc, fun) do
      reduce_(this, acc, fun)
    end

    def reduce_(_,     {:halt, acc}, _fun),   do: {:halted, acc}
    def reduce_(this,  {:suspend, acc}, fun), do: {:suspended, acc, &reduce(this, &1, fun)}
    def reduce_((%Q{length: 0}),    {:cont, acc}, _fun),   do: {:done, acc}
    def reduce_((%Q{} = this), {:cont, acc}, fun) do
      case Edata.Queue.take(this) do
        {element, rest} -> reduce(rest, fun.(element, acc), fun)
        #x -> raise "Shall not happen (#{inspect(x)})"
      end
    end
  end # Enumerable
end # module
