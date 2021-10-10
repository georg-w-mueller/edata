defmodule Edata.Datalog.Roptimizer do
  # alias __MODULE__, as: RO
  alias Edata.Datalog.Rumore, as: R
  alias Edata.Datalog.Facts, as: F
  alias Edata.Datalog.Misc, as: M

  # inline
  # order - facts first
  # drop repeated calls

  def opt(%R{ map: rm} = rules, %F{ map: _fm } = facts) do
    ilr = get_inline_rules(rules, facts)
    #ilre = expand_using(ilr, ilr)
    #IO.inspect(ilr)
    %R{ rules | map: expand_using(rm, ilr)}
  end

  def get_inline_rules(%R{ map: rm} = rules, %F{ map: _fm } = facts) do
    rm |> Map.keys
    |> Enum.filter(fn k ->
      R.rulesfor(rules, k) |> Enum.count == 1 &&      # |> Stream.reject(fn {pl, _} -> pl |> Enum.any?(fn p -> ! is_atom(p) end) end)
      F.factsfor(facts, k) |> Enum.count == 0
    end) |> Enum.reduce(%{}, fn k, m -> Map.put(m, k, R.rulesfor(rules, k)) end)
  end

  def expand_using(rm, inline) do
    rm |> Enum.map(fn {r, bodies} ->
    {r,
      bodies |> Enum.map(fn {rpar, body} ->
        {rpar, Enum.flat_map(body, fn l -> getsubst(inline, l, r) end ) |> M.distincttl()
        } end)
    } end )
    |> Map.new()
  end
 # O.getsubst(inl, {:nonzero, [:B]}, :div)

  #     nonzero a     div a b c
  def getsubst(_m, {_mod, _, _} = call, _lcall), do: [call]
  def getsubst(_m, {lcall, _par} = call, lcall), do: [call]
  def getsubst(m, {lcall, lpar} = call, _rcall) do
    case m |> Map.get( {lcall, length(lpar)}  ) do
      nil -> [call]
      [{spar, sbody}] -> adapt(lpar, spar, sbody)
        # mapping = M.mapargs(spar, lpar)
        # sbody |> Enum.map(
        #   fn {c, p} -> {c, M.maplocal(mapping, p)}
        #   {mod, c, p} -> {mod, c, M.maplocal(mapping, p)}
        # end)
      x -> IO.inspect(x); raise("unknown")
    end
  end

  def normalize_calls(%R{ map: _rm} = rules) do #, %F{ map: _fm } = facts
    ra = rarities(rules)
    ra |> Enum.filter(
      fn {_call, _total, [_sa]} -> false
          {_call, _total, [_hd | _tl]} -> true
      end)
    |> case do
      [] -> {:ok, normalize_(rules, ra)}
      x -> {:fail, x}
    end
  end

  def normalize_(%R{ map: rm}=rules, ra) do
    ra |> Stream.map(
      fn  {_call,  n, [sa]} when n == 1 or sa == 0 -> nil
          {call, _n, [_sa]} -> {call, R.rulesfor(rules, call)}
      end)
    |> Stream.filter(&(&1!=nil))
    |> Stream.map( fn c -> {call, [fr | others]} = c; {call, use_same_params(fr, others)} end )
    |> Enum.reduce( rm, fn {k, v}, m -> Map.update!(m, k, fn _ -> v end) end )
  end

  def use_same_params({fparams, _body} = fc, others) do
    [fc | others |> Enum.map(fn {op, ob} = clause ->
      case op == fparams do
        true -> clause
        _ -> {fparams, adapt(fparams, op, ob)}
      end
    end) ]
  end

  def adapt(fparams, op, ob) do
    mapping = M.mapargs(op, fparams)
    ob |> Enum.map(
      fn  {c, p} -> {c, M.maplocal(mapping, p)}
          {mod, c, p} -> {mod, c, M.maplocal(mapping, p)}
    end)
  end

  def rarities(%R{ map: rm} = _rules) do
    rm |> Enum.map(fn {r, bodies} ->
      {r, length(bodies), bodies |> Enum.map(fn {parl, _} -> length(parl) end) |> M.distincttl() }
    end)
  end

  def farities(%F{ map: fm } = _facts) do
    fm |> Enum.map(fn {r, arglsts} ->
      {r, length(arglsts), Enum.map(arglsts, fn al -> length(al) end) |> M.distincttl() }
    end)
  end

end
