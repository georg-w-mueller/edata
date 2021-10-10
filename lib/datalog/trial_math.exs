alias Edata.Datalog.Facts, as: F
alias Edata.Datalog.Ruless, as: R
alias Edata.Datalog.Misc, as: M

ints = F.new()
|> F.add(quote do int(0); int(1); int(2); int(3); int(4); int(5); int(6); int(7); int(8) end)  #; ; int(5); int(6); int(7); int(8)
|> F.add(quote do inc(0, 1); inc(1, 2); inc(2, 3); inc(3, 4); inc(4, 5); inc(5, 6); inc(6, 7); inc(7, 8) end) # ; inc(4, 5); inc(5, 6); inc(6, 7); inc(7, 8)
|> F.add(quote do zero(0); one(1) end)

mrs = R.new()
|> R.add(quote do dec(A, B) -> inc(B, A) end)
|> R.add(quote do nonzero(X) -> int(X); not zero(X) end)

|> R.add(quote do add(A, B, R) -> zero(A); zero(B); zero(R) end)

|> R.add(quote do add(A, B, R) -> zero(A); nonzero(B); int(R); eq(B, R) end)
|> R.add(quote do add(A, B, R) -> zero(B); nonzero(A); int(R); eq(A, R) end)

|> R.add(quote do add(A, B, R) -> nonzero(A); nonzero(B); dec(A, AD); inc(B, BI); any add(AD, BI, R) end)

|> R.add(quote do greater(A, B) -> zero(B); nonzero(A) end)
|> R.add(quote do greater(A, B) -> nonzero(A); nonzero(B); not eq(A, B); dec(A, AD); dec(B, BD); greater(AD, BD) end)

|> R.add(quote do less(A, B) -> greater(B, A) end)

|> R.add(quote do delta(A, B, D) -> int(A); int(B); eq(A, B); zero(D) end)
|> R.add(quote do delta(A, B, D) -> greater(A, B); add(B, D, A) end)
|> R.add(quote do delta(A, B, D) -> greater(B, A); add(A, D, B) end)

|> R.add(quote do sub(A, B, R) -> add(B, R, A) end)

|> R.add(quote do mult(A, B, R) -> zero(A); int(B); zero(R) end)
|> R.add(quote do mult(A, B, R) -> one(A); int(B); int(R); eq(B, R) end)
|> R.add(quote do mult(A, B, R) -> zero(B); greater_one(A); zero(R) end)
|> R.add(quote do mult(A, B, R) ->
  greater_one(A); nonzero(B);
  dec(A, AD); any mult(AD, B, RR); any add(B, RR, R)
end)

|> R.add(quote do greater_one(X) -> int(X); not zero(X); not one(X) end)

|> R.add(quote do div(A, B, R) -> nonzero(B); mult(B, R, A) end)

#r = R.ask_pure(mrs, ints, quote do add(A, B, R) end) |> Enum.to_list
#r = R.ask_pure(mrs, ints, quote do greater(A, B) end) |> Enum.to_list
#r = R.ask_pure(mrs, ints, quote do less(A, B) end) |> Enum.to_list
#r = R.ask_pure(mrs, ints, quote do delta(A, B, D) end) |> Enum.to_list
#r = R.ask_pure(mrs, ints, quote do sub(A, B, R) end) |> Enum.to_list


r = R.ask_pure(mrs, ints, quote do mult(X, Y, Z) end) |> Stream.map(&M.remove_ukeys(&1)) |> Enum.to_list
#r = R.ask_pure(mrs, ints, quote do greater_one(A) end) |> Enum.to_list
#r = R.ask_pure(mrs, ints, quote do div(X, Y, Z) end) |> Stream.map(&M.remove_ukeys(&1)) |> Enum.to_list
IO.inspect(r)
