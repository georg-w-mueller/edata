defmodule Edata.Transducer do

# reducing function signature:  whatever, input -> whatever
# transducer signature: (whatever, input -> whatever) -> (whatever, input -> whatever)

# stateful reducing function signature:  whatever, input -> whatever, nextreducef

  alias Edata.Queue, as: Q
  alias Edata.V8tree, as: V

  def map(f) when is_function(f) do
    fn rf ->
      fn
      :init           -> rf.(:init)
      {:stop, _result} = stop -> rf.(stop)
      {result, input} -> case rf.({result, f.(input)}) do
          {:cont, res, nextrf} -> {:cont, res, map(f).(nextrf)}
          res -> res  # implicit stop
        end
     end
    end
  end # map

  def filter(pred) when is_function(pred) do
    fn rf ->
      fn
      :init           -> rf.(:init)
      {:stop, _result} = stop -> rf.(stop)
      {result, input} = cont ->
        if pred.(input) do
          case rf.(cont) do
            {:cont, res, nextrf} -> {:cont, res, filter(pred).(nextrf)}
            res -> res  # implicit stop
          end
        else
          {:cont, result, filter(pred).(rf)}   #rf sufficient? - no
        end
      end
    end
  end # filter

  def take(0) do
    fn rf ->
      fn
        :init           -> rf.(:init)
        {:stop, result} -> rf.({:stop, result})
        {result, _}     -> rf.({:stop, result}) #{:cont, result, stop().(rf)}#{:stop, result}
        end # fn
    end # fn rf
  end # take 0

  def take(n) when is_integer(n) and n > 0 do
    fn rf ->
      fn
        :init           -> rf.(:init)
        {:stop, result} -> rf.({:stop, result})
        {_result, _input} = cont -> (
          # IO.puts(inspect([n, result, input ]))
          case rf.(cont) do
            {:cont, res, nextrf} ->  {:cont, res, take(n - 1).(nextrf)}
            res -> res
          end
        )
        end # fn
    end # fn rf
  end # take

  def drop(n) when is_integer(n) and n > 0 do
    fn rf ->
      fn
        :init           -> rf.(:init)
        {:stop, result} -> rf.({:stop, result})
        {result, _input}  -> (
          # IO.puts(inspect([n, result, input ]))
          {:cont, result, drop(n - 1).(rf)}
        )
        end # fn
    end # fn rf
  end # drop

  def drop(0) do
    fn rf ->
      fn
        :init           -> rf.(:init)
        {:stop, result} -> rf.({:stop, result})
        {_result, _input} = cont -> (
          case rf.(cont) do
               {:cont, res, nextrf} ->  {:cont, res, drop(0).(nextrf)}
               res -> res
          end
        )
        end # fn
    end # fn rf
  end #

  def stop() do
    fn rf ->
      fn
        :init -> rf.(:init)
        {:stop, result} -> rf.({:stop, result})
        {result, _} -> rf.({:stop, result})
      end
    end
  end

  def keep_last(n) when is_integer(n) and n > 0 do
    fn rf ->
      fn
        :init -> rf.(:init)
        {:stop, _result} = stop -> rf.(stop)
        {result, input} -> {:cont, result, keep_last_(n, Q.new(), input).(rf)}
        end # fn
    end # fn rf
  end # keep_last

  defp keep_last_(n, %Q{} = queue, element) when is_integer(n) and n > 0 do
    nqueue = ((if Q.size(queue) == n, do: Q.dropfirst(queue), else: queue) |> Q.add(element))
    fn rf ->
      fn
        {:stop, result} -> {:cont, result, release( Enum.to_list(nqueue) ).(rf)}
        {result, input} -> {:cont, result, keep_last_(n, nqueue, input).(rf)}
      end
    end
  end

  defp release([h|t]) do
    fn rf ->
      fn
        {:stop, result} ->
          case rf.({result,h}) do
            {:cont, res, nextrf} ->  {:cont, res, release(t).(nextrf)}
            r -> r
          end
        #{result, input} = nv -> IO.puts(inspect([:releasenonempty, result, input])); rf.(nv)
      end
    end
  end

  defp release([]) do
    fn rf ->
      fn
        {:stop, _result} = stop -> rf.(stop)
        #{result, input} = nv -> IO.puts(inspect([:releaseempty, result, input])); rf.(nv)
      end
    end
  end

  def partition(pred, cc \\ []) when is_function(pred) and is_list(cc) do
    fn rf ->
      fn
        :init   -> rf.(:init)
        {:stop, result} = stop ->
          #IO.puts(inspect([stop, cc ]))
          case cc do
            [] -> rf.(stop) # we're done
            _  -> case rf.({result,:lists.reverse(cc)}) do  # pass on the rest
              {:cont, res, nextrf} -> nextrf.({:stop, res}) # and state done //  #{:cont, res, partition(pred, []).(nextrf)}
              res -> #IO.puts(inspect([res, cc ]));
                res
            end
          end
        {result, input} -> (
          case cc do
            [] -> {:cont, result, partition(pred, [input]).(rf)}  # collect since we have not yet collected
            [h|_t] ->
              if pred.(input) == pred.(h) do  # continue collecting
                {:cont, result, partition(pred, [input | cc]).(rf)}
              else  # pass on recenct collection
                case rf.({result,:lists.reverse(cc)}) do
                  {:cont, res, nextrf} ->  {:cont, res, partition(pred, [input]).(nextrf)}
                  res -> #IO.puts(inspect([res, cc ]));
                    res
                end
              end
          end
        )
      end # fn
    end # fn rf
  end # partition

  def junk(n, cc \\ []) when is_integer(n) and n > 0 and is_list(cc) do
    fn rf ->
      fn
        :init -> rf.(:init)
        {:stop, result} = stop ->
          case (cc) do
            [] -> rf.(stop)
            _ -> case rf.({result, :lists.reverse(cc)}) do
              {:cont, res, nextrf} -> nextrf.({:stop, res})
              res -> res
            end
          end
        {result, input} ->
          ll = length( cc )
          if ll == (n - 1) do
            case rf.({result, :lists.reverse([input |cc])}) do
              {:cont, res, nextrf} ->  {:cont, res, junk(n, []).(nextrf)}
              res -> res
            end
          else
            {:cont, result, junk(n, [input | cc] ).(rf)}
          end
      end
    end
  end

  def roundrobin(n) when is_integer(n) and n>0 do
    fn rf ->
      fn :init -> rf.(:init)
        {:stop, _result} = stop -> rf.(stop)
        {result, input} -> {:cont, result, roundr_(V.new(n, []) |> V.set(0, [input]), 1).(rf) }
      end
    end
  end

  defp roundr_(%V{size: s}=this, nextslot) do
    ns = (if nextslot == s, do: 0, else: nextslot)
    fn rf ->
      fn {:stop, result} -> {:cont, result, release( this |> Enum.map(&(:lists.reverse(&1)))).(rf)  }
        {result, input} -> {:cont, result, roundr_(V.update(this, ns, fn e -> [input | e] end), ns+1).(rf)}
      end
    end
  end

  def unpack() do
    fn rf ->
      fn :init -> rf.(:init)
        {:stop, _r} = stop -> rf.(stop)
        {result, []} -> {:cont, result, unpack().(rf)}        # skip empty
        {result, [_h|_t] = input} -> case unpack_(result, rf, input) do
          {:cont, res, nextrf} ->  {:cont, res, unpack().(nextrf)}
          r -> IO.puts(inspect([:unpack, r]));
            #{:cont, r, unpack().(rf)}
            r
          end
      end
    end
  end

  defp unpack_(result, rf, []), do: {:cont, result, rf}
  defp unpack_(result, rf, [h| t]) do
    case rf.({result, h}) do
      {:cont, res, nextrf} -> unpack_(res, nextrf, t)
      r -> IO.puts(inspect([:localreduce, result, h, t, r]));
          r
    end
  end

  def group(keyf) when is_function(keyf,1) do
    fn rf ->
      fn :init -> rf.(:init)
        {:stop, _result} = stop -> rf.(stop)
        {result, input} -> {:cont, result, group_(keyf, %{keyf.(input) => [input]} ).(rf)}
      end
    end
  end

  def group_(keyf, mp) when is_function(keyf,1) and is_map(mp) do
    fn rf ->
      fn :init -> rf.(:init)
        {:stop, result} -> {:cont, result, release( Map.values(mp) ).(rf)}
        {result, input} -> {:cont, result, group_(keyf,
              Map.update(mp, keyf.(input), [input], fn lst -> [ input | lst] end )  ).(rf)
            }
      end
    end
  end

  def sort(keyf) when is_function(keyf) do
    fn rf -> unpack().(rf) |> group(keyf).() end
  end

  def join_enum(rhs, pred, comb) do
    mapper = fn e ->
      for el <- [e],
      er <- rhs,
        pred.(el, er) do
          comb.(el, er)
        end
     end
     fn rf -> unpack().(rf) |> map(mapper).() end
  end # join1

  def join_trans(rhs, pred, comb) when is_function(rhs,1) do
    # reduced = to_list() |> rhs.() # eager
    fn rf ->
      # join_enum(reduced, pred, comb).(rf)
      join_enum(to_list() |> rhs.(), pred, comb).(rf) # lazy
    end
  end

  # defp insert_return([single], ret) do
  #   fn rf ->
  #     {:stop, result} -> case rf.({result, single}) do
  #         {:cont, res, nextrf} ->  {:cont, res, ret}
  #         r -> r
  #       end
  #     {result, input} -> case rf.({result, single}) do
  #         {:cont, res, nextrf} ->  {:cont, res, ret}
  #         r -> r
  #       end
  #     end
  #   end
  # end

  def reduce(rf, enumerable) when is_function(rf) and is_list(enumerable) do
    init = rf.(:init)
    # IO.puts(inspect ([enumerable, init]) )
    reduce_(enumerable, init, rf)
  end

  def boildown(result, nrf) do
    #IO.puts("boiling")
    case nrf.({:stop, result}) do
      {:cont, r, f} -> boildown(r, f)
      r -> r
    end
  end

  defp reduce_([], acc, rf) do
    case rf.({:stop, acc}) do
      {:cont, result, nrf} -> boildown(result, nrf)#nrf.({:stop, result}) # yield, since a transducer continued
      res -> res
    end
  end
  defp reduce_([h | t], acc, rf) do
    red =  rf.({acc, h})
    # IO.puts(inspect ([h, t, acc, red]) )
    case red do
      {:stop, result} -> result
      {:cont, result, nrf} -> reduce_(t, result, nrf)  # transducer path
      result -> result  # simple reducer result path
    end
  end

  @doc "maps Enumerable.reduce-protocol to internal one"
  #def generic_reducer(rf) when is_function(rf, 1) do
  def generic_reducer(rf) do
    fn
      e, accumulator ->                       # stdcall Enumerable.reduce
        {acc, nrf} = case (accumulator) do    # first call or any but first
          {a, :nrf, f} -> {a, f}              # use new reducing fun
          _ -> {accumulator, rf}              # use initial rf
        end
      #IO.puts(inspect ( [:eaccnrf, e, acc, nrf] ))
      case nrf.({acc, e}) do
        {:cont, result, nrf} -> {:cont, {result, :nrf, nrf }} ## test [] !
        {:stop, result} -> #IO.puts(inspect([:suspend, result]));
          {:suspend, result}
        result -> #IO.puts(inspect([:result, result]));
          {:halt, result}
      end
    end
  end

  def reduce_generic(rf, enumerable) do
    gr = generic_reducer(rf)
    case Enumerable.reduce(enumerable, {:cont, rf.(:init)}, gr) do
      {:halted, r} -> r
      {:done, {a, :nrf, f}} -> boildown(a, f)
      #r -> IO.puts(inspect([:rrr, r])); r
    end
  end

  def count do
    fn
      :init -> 0
      {:stop, result} -> result
      {cn, _element} ->  {:cont, cn + 1, count()}
    end
  end

  def to_list do
    fn
      :init -> []
      {:stop, result} -> :lists.reverse(result)
      {c, element} ->  {:cont, [element | c ], to_list() }
    end
  end

  # def to_list_e do
  #   fn
  #     :init, _ -> []
  #     #{:stop, result} -> :lists.reverse(result)
  #     e, acc ->  {:cont, [e | acc ] }
  #     # {c, element, stack} --> ?!
  #   end
  # end
end # module
