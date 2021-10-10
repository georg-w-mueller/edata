defmodule Edata.Datalog.Base do

  defprotocol Ask do
    def ask(target, question)
    def ask?(target)
  end

  defimpl Ask, for: Any do
    def ask?(_f), do: false
    def ask(_, _), do: {false, []}
  end

end
