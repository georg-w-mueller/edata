alias Edata.Datalog.Facts, as: F
#alias Edata.Datalog.Ruless, as: R
alias Edata.Datalog.Misc, as: M

alias Edata.Datalog.Roptimizer, as: O

alias Edata.Datalog.Rumore, as: RM

ints = F.new()
|> F.add(quote do int(0..10) end)
|> F.add(quote do inc(0..9, 1..10) end)
|> F.add(quote do zero(0); one(1); end)
|> F.add(quote do add(0, 0, 0) end)

mrs = RM.new() |> RM.disallow_duppar()
|> RM.add(quote do dec(A, B) -> inc(B, A) end)
|> RM.add(quote do nonzero(X) -> int(X); not zero(X) end)

# |> RM.add(quote do add(A, B, R) -> zero(A); zero(B); zero(R) end)  # given as fact
|> RM.add(quote do add(A, B, R) -> zero(A); nonzero(B); int(R); eq(B, R) end)
|> RM.add(quote do add(A, B, R) -> zero(B); nonzero(A); int(R); eq(A, R) end)
|> RM.add(quote do add(A, B, R) -> dec(A, AD); nonzero(B); inc(B, BI); any add(AD, BI, R) end) # nonzero(A);

|> RM.add(quote do greater(A, B) -> zero(B); nonzero(A) end)
|> RM.add(quote do greater(A, B) -> nonzero(A); nonzero(B); not eq(A, B); dec(A, AD); dec(B, BD); greater(AD, BD) end)

|> RM.add(quote do less(A, B) -> greater(B, A) end)

|> RM.add(quote do delta(A, B, D) -> int(A); int(B); eq(A, B); zero(D) end)
|> RM.add(quote do delta(A, B, D) -> greater(A, B); add(B, D, A) end)
|> RM.add(quote do delta(A, B, D) -> greater(B, A); add(A, D, B) end)

|> RM.add(quote do sub(A, B, R) -> add(B, R, A) end)

|> RM.add(quote do mult(A, B, R) -> zero(A); int(B); zero(R) end)
|> RM.add(quote do mult(A, B, R) -> one(A); int(B); int(R); eq(B, R) end)
|> RM.add(quote do mult(A, B, R) -> zero(B); greater_one(A); zero(R) end)
|> RM.add(quote do mult(A, B, R) ->
  # greater_one(A); nonzero(B);
  # dec(A, AD); any mult(AD, B, RR); any add(B, RR, R)
  dec(A, AD); not zero(AD); nonzero(B);
  any mult(AD, B, RR); any add(B, RR, R)
end)

|> RM.add(quote do greater_one(X) -> int(X); not zero(X); not one(X) end)
|> RM.add(quote do div(A, B, R) -> nonzero(B); mult(B, R, A) end)

mrs_o = O.opt(mrs, ints)

mrm = RM.new()
|> RM.add(quote do dec(A, B) -> inc(B, A) end)
|> RM.add(quote do nonzero(X) -> int(X); not zero(X) end) #  1..9

# |> RM.add(quote do add(0, 0, 0) -> eq() end)  # given as fact
# |> RM.add(quote do add(0, B, R) -> nonzero(B); int(R); eq(B, R) end)
|> RM.add(quote do add(0, R, R) -> nonzero(R) end)
# |> RM.add(quote do add(A, 0, R) -> nonzero(A); int(R); eq(A, R) end)
|> RM.add(quote do add(R, 0, R) -> nonzero(R) end)
|> RM.add(quote do add(A, B, R) -> nonzero(A); nonzero(B); dec(A, AD); inc(B, BI); any add(AD, BI, R) end)

|> RM.add(quote do greater(A, 0) -> nonzero(A) end)
|> RM.add(quote do greater(A, B) -> nonzero(A); nonzero(B); not eq(A, B); dec(A, AD); dec(B, BD); greater(AD, BD) end)

|> RM.add(quote do less(A, B) -> greater(B, A) end)

|> RM.add(quote do delta(A, B, 0) -> int(A); int(B); eq(A, B) end)
|> RM.add(quote do delta(A, B, D) -> greater(A, B); add(B, D, A) end)
|> RM.add(quote do delta(A, B, D) -> greater(B, A); add(A, D, B) end)

|> RM.add(quote do sub(A, B, R) -> add(B, R, A) end)

|> RM.add(quote do mult(0, B, 0) -> int(B) end)
# |> RM.add(quote do mult(1, B, R) -> int(B); int(R); eq(B, R) end)
|> RM.add(quote do mult(1, R, R) -> int(R) end)
|> RM.add(quote do mult(A, 0, 0) -> greater_one(A) end)
|> RM.add(quote do mult(A, B, R) ->
  # greater_one(A); nonzero(B);
  # dec(A, AD); any mult(AD, B, RR); any add(B, RR, R)
  dec(A, AD); not zero(AD); nonzero(B);
  any mult(AD, B, RR); any add(B, RR, R)
end)

|> RM.add(quote do greater_one(X) -> int(X); not zero(X); not one(X) end) #  2..9
|> RM.add(quote do div(A, B, R) -> nonzero(B); mult(B, R, A) end)

# mrso = O.opt(mrs, ints)

mrm_o = O.opt(mrm, ints)

query = quote do mult(X, Y, Z) end

Benchee.run(%{
  "mrs" => fn -> RM.ask_pure(mrs, ints, query ) |> Enum.to_list end,
  "mrs_o" => fn -> RM.ask_pure(mrs_o, ints, query ) |> Enum.to_list end,
  "mrm" => fn -> RM.ask_pure(mrm, ints, query ) |> Enum.to_list end,
  "mrm_o" => fn -> RM.ask_pure(mrm_o, ints, query ) |> Enum.to_list end
}, time: 40, parallel: 2)

# send helper1, :stop
# send helper2, :stop
# send helper3, :stop
