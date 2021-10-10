defmodule Edata.Zipper do

  def zipper(l) when is_list(l) do
    {:ok, [], l}
  end

  @doc "current element"
  def current({:error, _, _} = this), do: this
  def current({:ok, p, l} = this) when is_list(p) and is_list(l) do
    case l do
      [h | _t] -> {:ok, h}
      _ -> {:error, "No current element in #{inspect(this)}"}
    end
  end

  @doc "zipper for next element"
  def next({:error, _, _} = this), do: this
  def next({:ok, p, l} = this) when is_list(p) and is_list(l) do
    case l do
      [h | t] -> {:ok, [h | p], t}
      _ -> {:error, "Cannot proceed to next in #{inspect(this)}", this}
    end
  end

  @doc "zipper for prev element"
  def prev({:error, _, _} = this), do: this
  def prev({:ok, p, l} = this) when is_list(p) and is_list(l) do
    case p do
      [h | t] -> {:ok, t, [h | l]}
      _ -> {:error, "Cannot proceed to previous in #{inspect(this)}, this"}
    end
  end

  def reduce({:error, _, _}, acc, _fun), do: acc
  def reduce({:ok, _, _} = this, acc, fun) do
    case current(this) do
      {:error, _} -> acc
      {:ok, element} -> reduce(next(this), fun.(element, acc), fun)
    end
  end
end # module
