defmodule Edata.Tst do
  require Edata.Rfn

  def ra() do
    Edata.Rfn.make_rec(fn
      [], result -> result
      [num | next], result -> __REC__(next, num + result)
    end)
  end
end
