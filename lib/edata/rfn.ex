defmodule Edata.Rfn do
  require Logger
  defmacro make_rec({:fn, ctx, patterns} = target) do
    Logger.info(target |> Macro.to_string())
    arity = get_arity(patterns)
    new_patterns = patterns |> Enum.map(&insert_rec_fn/1)
    ast = {:fn, ctx, new_patterns}

    Logger.info(ast |> Macro.to_string())

    quote do
      f = unquote(ast)
      Edata.Rfn.make_fn_arity(f, unquote(arity))
    end
  end

  defmacro make_fn_arity(f, arity) do
    r = {:&, [], [{{:., [], [f]}, [], [f | 1..arity |> Enum.map(&{:&, [], [&1]})]}]}
    Logger.info(r |> Macro.to_string())
    r
  end

  defp insert_rec_fn({:->, _, [_arg_list, _]} = pattern) do
    {pattern, mod?} =
      Macro.postwalk(pattern, false, fn
        {:__REC__, _, arg_list}, _ when is_list(arg_list) ->
          re = {{:., [], [{:rec__, [], nil}]}, [], [{:rec__, [], nil} | arg_list]}
          {re, true}

        other, mod? ->
          {other, mod?}
      end)

    arg_name =
      if mod? do
        :rec__
      else
        :__REC__
      end

    update_in(pattern, [Access.elem(2), Access.at(0)], &[{arg_name, [], nil} | &1])
  end

  defp get_arity([{:->, _, [arg_list, _]} | _]) do
    length(arg_list)
  end
end
