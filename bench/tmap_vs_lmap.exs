alias Edata.Datalog.Tuplematch, as: TM

zp = fn enum -> enum |> Enum.zip(enum |> Enum.drop(1)) end

b1l = TM.nkicks(4001, 1)
b1t = b1l |> TM.lsts_tt()

b1 = b1l |> zp.()
t1 = b1t |> zp.()

b2l = TM.nkicks(4001, 2)
b2t = b2l |> TM.lsts_tt()

b2 = b2l |> zp.()
t2 = b2t |> zp.()

b3l = TM.nkicks(4001, 3)
b3t = b3l |> TM.lsts_tt()

b3 = b3l |> zp.()
t3 = b3t |> zp.()

Benchee.run(%{
  # "b1 l" => fn -> b1 |> Stream.map( fn {p, a} -> TM.lbind(p, a) end) |> Stream.run() end,
  "b1 c" => fn -> b1 |> Stream.map( fn {p, a} -> TM.lbind_c(p, a) end) |> Stream.run() end,
  "b1 c kw" => fn -> b1 |> Stream.map( fn {p, a} -> TM.lbind_c_kw(p, a) end) |> Stream.run() end,
  # "b1 w" => fn -> b1 |> Stream.map( fn {p, a} -> TM.lbind_w(p, a) end) |> Stream.run() end,
  # "t1" => fn -> t1 |> Stream.map( fn {p, a} -> TM.tbind(p, a) end) |> Stream.run() end,

  # "b2 l" => fn -> b2 |> Stream.map( fn {p, a} -> TM.lbind(p, a) end) |> Stream.run() end,
  "b2 c" => fn -> b2 |> Stream.map( fn {p, a} -> TM.lbind_c(p, a) end) |> Stream.run() end,
  "b2 c kw" => fn -> b2 |> Stream.map( fn {p, a} -> TM.lbind_c_kw(p, a) end) |> Stream.run() end,
  # "b2 w" => fn -> b2 |> Stream.map( fn {p, a} -> TM.lbind_w(p, a) end) |> Stream.run() end,
  # "t2" => fn -> t2 |> Stream.map( fn {p, a} -> TM.tbind(p, a) end) |> Stream.run() end,

  # "b3 l" => fn -> b3 |> Stream.map( fn {p, a} -> TM.lbind(p, a) end) |> Stream.run() end,
  "b3 c" => fn -> b3 |> Stream.map( fn {p, a} -> TM.lbind_c(p, a) end) |> Stream.run() end,
  "b3 c kw" => fn -> b3 |> Stream.map( fn {p, a} -> TM.lbind_c(p, a) end) |> Stream.run() end,
  # "b3 w" => fn -> b3 |> Stream.map( fn {p, a} -> TM.lbind_w(p, a) end) |> Stream.run() end,
  # "t3" => fn -> t3 |> Stream.map( fn {p, a} -> TM.tbind(p, a) end) |> Stream.run() end
})
