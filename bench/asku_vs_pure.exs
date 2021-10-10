alias Edata.Datalog.Facts, as: F
alias Edata.Datalog.Ruless, as: R
alias Edata.Datalog.Misc, as: M
alias Edata.Datalog.Roptimizer, as: O

# alias Edata.Datalog.Rumore, as: RM

ints = F.new()
|> F.add(quote do int(0); int(1); int(2); int(3); int(4) end)  #; ; int(5); int(6); int(7); int(8)
|> F.add(quote do inc(0, 1); inc(1, 2); inc(2, 3); inc(3, 4) end) # ; inc(4, 5); inc(5, 6); inc(6, 7); inc(7, 8)
|> F.add(quote do zero(0); one(1); two(2) end)

mrs = R.new()
|> R.add(quote do dec(A, B) -> inc(B, A) end)
|> R.add(quote do nonzero(X) -> int(X); not zero(X) end)

|> R.add(quote do add(A, B, R) -> zero(A); zero(B); zero(R) end)

|> R.add(quote do add(A, B, R) -> zero(A); nonzero(B); int(R); eq(B, R) end)
|> R.add(quote do add(A, B, R) -> zero(B); nonzero(A); int(R); eq(A, R) end)

|> R.add(quote do add(A, B, R) -> dec(A, AD); nonzero(B); inc(B, BI); any add(AD, BI, R) end) # nonzero(A);

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
  # greater_one(A); nonzero(B);
  # dec(A, AD); any mult(AD, B, RR); any add(B, RR, R)
  dec(A, AD); not zero(AD); nonzero(B);
  any mult(AD, B, RR); any add(B, RR, R)
end)

|> R.add(quote do greater_one(X) -> int(X); not zero(X); not one(X) end)

|> R.add(quote do div(A, B, R) -> nonzero(B); mult(B, R, A) end)

mrso = O.opt(mrs, ints)

ints6 = ints  |> F.add(quote do int(5); int(6); inc(4, 5); inc(5, 6) end)
ints8 = ints6 |> F.add(quote do int(7); int(8); inc(6, 7); inc(7, 8) end)

query = quote do mult(X, Y, Z) end

# helper1 = M.init_loop()
# helper2 = M.init_loop()
# helper3 = M.init_loop

Benchee.run(%{
  "ints8" => fn -> R.ask_pure(mrs, ints8, query ) |> Enum.to_list end,
  "ints8 O" => fn -> R.ask_pure(mrso, ints8, query ) |> Enum.to_list end,
#  "ints8 + logging" => fn -> R.ask_pure(mrs, ints8, query , helper3) |> Enum.to_list end,
  "ints" => fn -> R.ask_pure(mrs, ints, query ) |> Enum.to_list end,
  "ints O" => fn -> R.ask_pure(mrso, ints, query ) |> Enum.to_list end,
#  "ints + logging" => fn -> R.ask_pure(mrs, ints, query , helper1) |> Enum.to_list end,
  "ints6" => fn -> R.ask_pure(mrs, ints6, query ) |> Enum.to_list end,
  "ints6 O" => fn -> R.ask_pure(mrso, ints6, query ) |> Enum.to_list end
#  "ints6 + logging" => fn -> R.ask_pure(mrs, ints6, query , helper2) |> Enum.to_list end
})

# send helper1, :stop
# send helper2, :stop
# send helper3, :stop
