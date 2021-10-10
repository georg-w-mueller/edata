alias Edata.StreamTrial, as: ST

base = 1..100
input = Stream.cycle(base) |> Enum.take(10_000)
reducer = &(Enum.count(&1))

Benchee.run(%{
  "distinct" => fn -> ST.distinct( input ) |> reducer.() end,
  "distinct_man" => fn -> ST.distinct_man( input ) |> reducer.() end,
  "distinct_mapset" => fn -> ST.distinct_mapset( input ) |> reducer.() end,
  "distinct_crafted" => fn -> ST.distinct_crafted( input ) |> reducer.() end,
})

# to_list
# Name                       ips        average  deviation         median         99th %
# distinct_crafted        285.09        3.51 ms    ┬▒30.47%        3.10 ms        7.98 ms
# distinct_mapset         175.64        5.69 ms   ┬▒132.93%           0 ms          16 ms
# distinct_man             60.02       16.66 ms    ┬▒35.48%          16 ms          32 ms
# distinct                 33.79       29.59 ms    ┬▒35.07%          31 ms          63 ms

# Comparison:
# distinct_crafted        285.09
# distinct_mapset         175.64 - 1.62x slower
# distinct_man             60.02 - 4.75x slower
# distinct                 33.79 - 8.44x slower
