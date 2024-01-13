import map, filter, id, flatten, dump, type from require "xi.utils"
import Span from require "xi.span"
import Fraction from require "xi.fraction"
import Event from require "xi.event"
import State from require "xi.state"
-- import mini from require "xi.mini.interpreter"

bit = require "bitop.funcs"

P = {}

-- TODO: maybe rename m_func
-- TODO: do patternify the strudel & tidal way
class Pattern
  new:(query = -> {}) =>
    @query = query

  type: -> "pattern"

  querySpan:(b, e) =>
    span = Span b, e
    state = State span
    @query state

  firstCycle: => @querySpan 0, 1

  __tostring: =>
    func = (event) -> event\show!
    dump map func, @firstCycle!

  show: => @__tostring!

  __eq: (other) => @show! == other\show!

  bindWhole: (choose_whole, func) =>
    print func
    pat_val = @
    query = (_, state) ->
      withWhole = (a, b) ->
        Event (choose_whole a.whole, b.whole), b.part, b.value --context?
      match = (a) ->
        events = func(a.value)\query(state\setSpan a.part)
        map ((b) -> withWhole a, b), events
      events = pat_val\query(state)
      flatten (map ((a) -> match a), events)
    Pattern query

  outerBind:(func) => @bindWhole ((a) -> a), func

  innerBind:(func) => @bindWhole((_, b) -> b, func)

  outerJoin: => @outerBind id

  innerJoin: => @innerBind id

  filterEvents:(func) =>
    query = (_, state) ->
      events = @query state
      filter func, events
    Pattern query

  splitQueries: =>
    query = (_, state) ->
      cycles = state.span\spanCycles!
      m_func = (span) ->
        sub_state = state\setSpan span
        @query sub_state
      flatten map m_func, cycles
    Pattern query

  withValue:(func) =>
    query = (_, state) ->
      events = @query state
      m_func = (event) ->
        return event\withValue func
      map m_func, events
    Pattern query

  fmap:(func) => @withValue(func)

  withQuerySpan:(func) =>
    query = (_, state) ->
      new_state = state\withSpan func
      @query new_state
    Pattern query

  withQueryTime:(func) =>
    @withQuerySpan (span) ->span\withTime func

  withTime:(q_func, e_func) =>
    query = @withQueryTime q_func
    pattern = query\withEventTime e_func
    pattern

  withEventTime:(func) =>
    query = (_, state) ->
      events = @query state
      time_func = (span) -> span\withTime func
      event_func = (event) -> event\withSpan time_func
      map event_func, events
    Pattern query

  onsetsOnly: => @filterEvents (event) -> event\hasOnset!

  _patternify:(method) =>
    patterned = (patSelf, ...) ->
      patArg = sequence ...
      return patArg\fmap((arg) -> method(patSelf, arg))\outerJoin!
    return patterned

  _fast:(factor) => @withTime ((t) -> t * factor), ((t) -> t / factor)

  -- fast: => Pattern\_patternify((patSelf, val) -> patSelf\_fast(val))

  -- offset might be fraction?
  _early:(offset) => @withTime ((t) -> t + offset), ((t) -> t - offset)

  _slow:(value) => @_fast 1 / value

  _late:(offset) => @_early -offset

  -- need patternify
  fastgap:(factor) =>
    if type(factor) != "fraction"
      factor = Fraction(factor)

    if factor <= Fraction(0)
      P.silence!

    factor = factor\max(1)

    mungeQuery = (t) ->
      t\sam! + ((t - t\sam!) * factor)\min(1)

    eventSpanFunc = (span) ->
      b = span._begin\sam! + (span._begin - span._begin\sam!) / factor
      e = span._begin\sam! + (span._end - span._begin\sam!) / factor
      Span b, e

    query = (_, state) ->
      span = state.span
      new_span = Span mungeQuery(span._begin), mungeQuery(span._end)
      if new_span._begin == new_span._begin\nextSam!
        return {}
      new_state = State new_span
      events = @query new_state
      m_func = (event) ->
        event\withSpan eventSpanFunc
      map m_func, events
    Pattern(query)\splitQueries!

  compress:(b, e) =>
    if type(b) != "fraction" and type(e) != "fraction"
      b, e = Fraction(b), Fraction(e)
    if b > e or e > Fraction(1) or b > Fraction(1) or b < Fraction(0) or e < Fraction(0)
      P.silence!
    @fastgap(Fraction(1) / (e - b))\_late(b)

  degrade_by:(by, prand = nil) =>
    if by == 0
      return @
    if not prand
      prand = P.rand!
    return @fmap((val) -> (_) -> val)\appLeft(prand\_filter_values((v) -> v > by))

  -- TODO: tests for this
  appLeft:(pat_val) =>
    query = (_, state) ->
      events = {}
      event_funcs = @query state
      for event_func in *event_funcs
        whole = event_func\wholeOrPart!
        event_vals = pat_val\querySpan(whole._begin, whole._end)
        for event_val in *event_vals
          new_whole = event_func.whole
          new_part = event_func.part\sect event_val.part
          if new_part ~= nil
            new_value = event_func.value event_val.value
            print new_whole
            table.insert events, Event new_whole, new_part, new_value
      return events
    Pattern query

  appRight:(pat_val) =>
    query = (_, state) ->
      events = {}
      event_vals = pat_val\query state
      for event_val in *event_vals
        -- HACK: tmp hack? or is this the better solution?
        whole = event_val\wholeOrPart!
        event_funcs = @querySpan(whole._begin, whole._end)
        event_val\wholeOrPart!
        for event_func in *event_funcs
          new_whole = event_val.whole
          new_part = event_func.part\sect event_val.part
          if new_part ~= nil
            new_value = event_func.value event_val.value
            -- context
            table.insert events, Event new_whole, new_part, new_value
        return events
    Pattern query

P.silence = -> Pattern!

P.pure = (value) ->
  query = (state) =>
    cycles = state.span\spanCycles!
    m_func = (span) ->
      whole = span\wholeCycle span._begin
      Event whole, span, value
    map m_func, cycles
  Pattern query

P.reify = (pat) ->
  if type(pat) == "pattern"
    return pat
  -- if type(pat) == "string"
  -- 	return mini pat
  P.pure pat

P.stack = (...) ->
  pats = ...
  if type(pats) == "table"
    pats = ...
  else
    pats = { ... }
  pats = map P.reify, pats
  query = (state) =>
    events = map ((pat) -> pat\query state), pats
    flatten events
  Pattern query

-- is prime
P.slowcat = (...) ->
  pats = ...
  if type(pats) == "table"
    pats = ...
  else
    pats = { ... }
  pats = map P.reify, pats
  query = (state) =>
    len = #pats
    index = state.span._begin\sam!\asFloat! % len + 1
    pat = pats[index]
    pat\query state
  Pattern(query)\splitQueries!

-- TODO:ABSTRACT tablize
-- HACK: is passing floats around a good idea?
P.fastcat = (...) ->
  pats = ...
  if type(pats) == "table"
    pats = ...
  else
    pats = { ... }
  pats = map P.reify, pats
  P.slowcat(...)\_fast(#pats)

P.timecat = (time_pat_tuples) ->
  tuples, arranged = {}, {}
  accum, total = 0, 0
  for tup in *time_pat_tuples
    { time, pat } = tup
    table.insert tuples, { time, pat }
    total = total + time

  for tup in *tuples
    { time, pat } = tup
    table.insert arranged, { accum / total, (accum + time) / total, P.reify(pat) }
    accum = accum + time

  n_pats = {}
  for tab in *arranged
    { b, e, pat } = tab
    table.insert n_pats, pat\compress(b, e)

  P.stack(n_pats)

signal = (func) ->
  query = (state) =>
    return Event nil, state.span, func(state.span\midpoint!)
  Pattern query

xorwise = (x) ->
  a = bit.bxor((bit.lshift(x,13)), x)
  b = bit.bxor((bit.rshift(a,17)), a)
  bit.bxor((bit.lshift(b,5)), b)

_frac = (x) -> x - math.floor x

timeToIntSeed = (x) -> 
  xorwise math.floor (_frac(x\asFloat! / 300) * 536870912)

-- output a bit differnet than strudel??
intSeedToRand = (x) -> (x % 536870912) / 536870912

timeToRand = (x) -> math.abs intSeedToRand timeToIntSeed x

P.rand = -> signal timeToRand -- HACK: is this right?

seq_count = (x) ->
  if type(x) == "table"
    print "1"
    if #x == 1
      print "2"
      seq_count x[1]
    else
      print "3"
      pats = map sequence, x ---???
      P.fastcat(pats), #x
  elseif type(x) == "pattern"
    print "4"
    x, 1
  else
    print "5"
    M.pure(x), 1

P.sequence = (x) ->
  seq, _ = seq_count(x)
  seq

P.fast = (arg, pat) -> P.reify(pat)\_fast(arg) --TODO: use patternified version later
P.slow = (arg, pat) -> P.reify(pat)\_slow(arg) --TODO: use patternified version later

Pattern.fast = Pattern\_patternify((patSelf, val) -> patSelf\_fast(val))

P.Pattern = Pattern


print type P.pure(1)\fast(2)


return P
