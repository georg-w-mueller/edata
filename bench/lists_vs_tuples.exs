alias Edata.Datalog.Tuplematch, as: TM

zp = fn enum -> enum |> Enum.zip(enum |> Enum.drop(1)) end

tb = fn enum -> enum |> Enum.map(&(:erlang.list_to_binary(&1))) end

domain = 1..255 |> Enum.to_list

b2l = TM.nkicks(12001, 8, domain)
b2t = b2l |> TM.lsts_tt()
b2b = b2l |> tb.()

l2 = b2l |> zp.()
t2 = b2t |> zp.()
b2 = b2b |> zp.()

Benchee.run(%{
  "l 2" => fn -> l2 |> Stream.map( fn {p, a} -> p == a end) |> Stream.run() end,
  "t 2" => fn -> t2 |> Stream.map( fn {p, a} -> p == a end) |> Stream.run() end,
  "b 2" => fn -> b2 |> Stream.map( fn {p, a} -> p == a end) |> Stream.run() end
})
