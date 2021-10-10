defmodule Edata.Joiner do
  alias __MODULE__, as: J

  #defstruct  left: [], right: [], pleft: fn _ -> true end #, pright: fn _ -> true end, fcomb: fn l, r -> {l, r} end
  defstruct  left: nil, right: nil, pred: nil, fcomb: nil

  defp default_pred(), do: fn _, _ -> true end
  defp default_comb(), do: fn l, r -> {l, r} end

  def new(l, r), do: %J{left: l, right: r, pred: default_pred(), fcomb: default_comb()}
  def new(l, r, pr), do: %J{ new(l, r) | pred: pr }
  def new(l, r, pr, fc), do: %J{ new(l, r, pr) | fcomb: fc }

  def renew(%J{} = joiner, l, r), do: %{joiner | left: l, right: r }
  def drop1left(%J{left: l} = joiner), do: %{joiner | left: Enum.drop(l, 1)}

  #def cross(%J{left: []}), do: []
  #def cross(%J{right: []}), do: []
  def cross(%J{left: l, right: r, pred: pr, fcomb: fc}) do
    for el <- l,
        er <- r,
        pr.(el, er) do
          fc.(el, er)
        end
  end # cross

  def cross_ex(%J{} = joiner) do
    cex_(iterator(joiner), [])
  end # cross_ex

  def cex_( {:fin, _}, res), do: :lists.reverse(res)
  def cex_( {:ok, it}, res) do
    {hit, n} = it
    cex_( next(n), [hit | res])
  end

  def iterator(%J{left: l, right: r} = joiner) do
    if (Enum.empty?(l) || Enum.empty?(r)) do
      {:fin, nil}
    else
      current = Enum.at(l, 0)
      second_skipped = Enum.drop_while(r, fn e -> not (joiner.pred).(current, e) end)
      case second_skipped	do
        [] -> iterator(drop1left( joiner))
        [hit | rest] -> {:ok, iterator_(current, hit, rest, joiner)}
      end
    end
  end # iterator

  defp iterator_(current, hit, [], joiner) do
    {joiner.fcomb.(current, hit), drop1left(joiner)}
  end # iterator_
  defp iterator_(current, hit, rest, joiner) do
    {joiner.fcomb.(current, hit), {current, rest, joiner}}
  end # iterator_

  def next(%J{}=j), do: iterator(j)
  def next({_current, [], joiner}), do: iterator(drop1left(joiner))
  def next({current, [h | rest], %J{}=joiner}) do
    if (joiner.pred.(current, h)) do
      {:ok, iterator_(current, h, rest, joiner)}
    else
      next({current, rest, joiner})
    end
  end
end # module
