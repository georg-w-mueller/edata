defmodule RfnTest do

  require Edata.Rfn
  use ExUnit.Case

  test   "rec_add" do
    sum =
      Edata.Rfn.make_rec(fn
        [], result -> result
        [num | next], result -> __REC__(next, num + result)
      end)

    assert is_function(sum, 2)
    assert 6 == sum.([1, 2, 3], 0)
  end

end
