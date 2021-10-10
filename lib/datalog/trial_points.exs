alias Edata.Datalog.Facts, as: F
alias Edata.Datalog.Ruless, as: R

facts = F.new()
|> F.add(quote do point(a); point(b); point(c); point(r); point(s) end) #; point(d)
|> F.add(quote do edge(a,b); edge(b,c); edge(r,s) end)  #; edge(c,d)

rules = R.new()
#|> R.add(quote do dirconn(X,Y) -> point(X); point(Y); edge(X,Y) end)
|> R.add(quote do conn(X,Y) -> edge(X,M); conn(M,Y) end)
|> R.add(quote do conn(X,Y) -> edge(X,Y) end)
|> R.add(quote do anyconn(A, B) -> any conn(A, B) end)
|> R.add(quote do notconn(A, B) -> point(A); point(B); not eq(A, B); not anyconn(A, B) end)

IO.inspect(facts)
IO.inspect(rules)
#r1 = R.ask_pure(rules, facts, quote do edge(A, B) end) |> Enum.to_list
r2 = R.ask_pure(rules, facts, quote do anyconn(A, B) end) |> Enum.to_list

IO.inspect(r2)
#R.ask_pure(rules, facts, quote do notconn(A, B) end) |> Enum.to_list

# Stream.into([1, 2], x, &(inspect(&1))) |> Stream.run()
