alias Edata.Datalog.Facts, as: F
alias Edata.Datalog.Rumore, as: R
alias Edata.Datalog.Misc, as: M

ints = F.new()
|> F.add(quote do int(0..12) end)
|> F.add(quote do inc(0..11, 1..12) end)
|> F.add(quote do zero(0); one(1) end)
|> F.add(quote do add(0, 0, 0) end)

mrs = R.new()
#|> R.add(quote do int(X) -> 0..6 end)
|> R.add(quote do dec(A, B) -> inc(B, A) end)
|> R.add(quote do nonzero(X) -> int(X); not zero(X) end)

#|> R.add(quote do add(0, 0, 0) -> eq() end)

#|> R.add(quote do add(0, B, R) -> nonzero(B); int(R); eq(B, R) end)
|> R.add(quote do add(0, R, R) -> nonzero(R) end)
# |> R.add(quote do add(A, 0, R) -> nonzero(A); int(R); eq(A, R) end)
|> R.add(quote do add(R, 0, R) -> nonzero(R) end)
# |> R.add(quote do add(0, B, B) -> nonzero(B) end)
# |> R.add(quote do add(A, 0, A) -> nonzero(A) end)

|> R.add(quote do add(A, B, R) -> nonzero(A); nonzero(B); dec(A, AD); inc(B, BI); any add(AD, BI, R) end)

|> R.add(quote do greater(A, B) -> zero(B); nonzero(A) end)
|> R.add(quote do greater(A, B) -> nonzero(A); nonzero(B); not eq(A, B); dec(A, AD); dec(B, BD); greater(AD, BD) end)

|> R.add(quote do less(A, B) -> greater(B, A) end)

|> R.add(quote do delta(A, B, D) -> int(A); int(B); eq(A, B); zero(D) end)
|> R.add(quote do delta(A, B, D) -> greater(A, B); add(B, D, A) end)
|> R.add(quote do delta(A, B, D) -> greater(B, A); add(A, D, B) end)

|> R.add(quote do sub(A, B, R) -> add(B, R, A) end)

|> R.add(quote do mult(0, B, 0) -> int(B) end)
# |> R.add(quote do mult(1, B, R) -> int(B); int(R); eq(B, R) end)
|> R.add(quote do mult(1, R, R) -> int(R) end)
|> R.add(quote do mult(A, 0, 0) -> greater_one(A) end)
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
