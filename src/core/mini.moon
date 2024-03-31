--- defines the PEG grammar for parsing mini-notation
-- @module mini.grammar
import P, S, V, R, C, Ct, Cc from require("lpeg")
local *
require "moon.all"

-- unpack = unpack or table.unpack
tinsert = table.insert

sequence = V "sequence"
group = V "group"
slice = V "slice"
sub_cycle = V "sub_cycle"
polymeter = V "polymeter"
slow_sequence = V "slow_sequence"
polymeter_steps = V "polymeter_steps"
stack = V "stack"
stack_or_choose = V "stack_or_choose"
polymeter_stack = V "polymeter_stack"
dotStack = V "dotStack"
choose = V "choose"
step = V "step"
slice_with_ops = V "slice_with_ops"
op = V "op"
fast = V "fast"
slow = V "slow"
replicate = V "replicate"
degrade = V "degrade"
weight = V "weight"
euclid = V "euclid"
tail = V "tail"
range = V "range"

AtomStub = (source) ->
  return {
    type: "atom"
    source: source
    -- location: location() --?
  }

PatternStub = (source, alignment, seed) ->
  return {
    type: "pattern"
    arguments: { alignment: alignment, seed: seed } -- ? what condition?
    source: source
  }

ElementStub = (source, options) ->
  return {
    type: "element"
    source: source
    options: options
    -- location: location! -- ?
  }


id = (x) -> x

seed = -1 -- neccesary???
--- non-recersive rules
-- delimiters
ws = S" \n\r\t" ^ 0
comma = ws * P"," * ws
pipe = ws * P"|" * ws
dot = ws * P"." * ws
quote = P"'" + P'"'

parseNumber = (num) -> tonumber num
parseStep = (chars) ->
  -- p chars
  if chars != "." and chars != "_" then return AtomStub chars

-- chars
step_char = R("09", "AZ", "az") + P"-" + P"#" + P"." + P"^" + P"_" + P"~" / id -- upgrade to unicode
step = ws * (step_char ^ 1 / parseStep) * ws - P"."

-- numbers
minus = P("-")
plus = P("+")
zero = P("0")
digit = R("09")
decimal_point = P(".")
digit1_9 = R("19")
e = S("eE")
int = zero + (digit1_9 * digit ^ 0)
intneg = minus ^ -1 * int
exp = e * (minus + plus) ^ -1 * digit ^ 1
frac = decimal_point * digit ^ 1
number = (minus ^ -1 * int * frac ^ -1 * exp ^ -1) / parseNumber

parseFast = (a) ->
  (x) -> tinsert x.options.ops, { type: "stretch", arguments: { amount: a, type: "fast" } }

parseSlow = (a) ->
  (x) -> tinsert x.options.ops, { type: "stretch", arguments: { amount: a, type: "slow" } }

parseTail = (s) ->
  (x) -> tinsert x.options.ops, { type: "tail", arguments: { element: s } }

parseRange = (s) ->
  (x) -> tinsert x.options.ops, { type: "range", arguments: { element: s } }

parseDegrade = (a) ->
  if type(a) == "number" then a = tonumber(a)
  else a = nil
  (x) ->
    seed += 1
    tinsert x.options.ops, { type: "degradeBy", arguments: { amount: a, seed: seed } }

parseEuclid = (p, s, r = 0) ->
  (x) -> tinsert x.options.ops, { type: "euclid", arguments: { pulse: p, steps: s, rotation: r } }

parseWeight = (a) ->
  (x) -> x.options.weight = ( x.options.weight or 1 ) + ( tonumber(a) or 2 ) - 1

parseReplicate = (a) ->
  (x) -> x.options.reps = ( x.options.reps or 1 ) + ( tonumber(a) or 2 ) - 1

parseSlices = (slice, ...) ->
  -- p slice
  ops = { ... }
  result = ElementStub(slice, { ops: {}, weight: 1, reps: 1})
  for op in *ops
    op(result)
  return result

parsePolymeter = (s, steps) ->
  s = PatternStub({s}, "polymeter")
  s.arguments.stepsPerCycle = steps
  return s

parseSlowSeq = (s, steps) ->
  s = PatternStub({s}, "polymeter_slowcat")
  -- s.arguments.alignment = "polymeter_slowcat"
  return s

parseDotTail = (...) -> { alignment: "feet", list: { ... }, seed: seed + 1 }

parseStack = (...) -> PatternStub({ ... }, "stack")

parseDotStack = (...) ->
  -- p ...
  seed += 1
  PatternStub({ ... }, "feet", seed)

parseChoose = (...) ->
  seed += 1
  PatternStub({ ... }, "rand", seed)

parseStackOrChoose = (head, tail) ->
  -- p tail
  if tail and #tail.list > 0
    return PatternStub({ head, unpack(tail.list) }, tail.alignment, tail.seed)
  else
    return head


parseSequence = (...) ->
  PatternStub({ ... }, "fastcat")

parseSubCycle = (s) -> s

--- table of PEG grammar rules
-- @table grammar
grammar = {
  "root" -- initial rule
  -- choose: sequence * (choose_tail) ^ -1
  -- root: stack_or_choose + polymeter_stack
  root: dotStack + choose + stack + sequence

  -- sequence and tail
  sequence: (slice_with_ops ^ 1) / parseSequence
  stack: sequence * (comma * sequence) ^ 1 / parseStack
  choose: sequence * (pipe * sequence) ^ 1 / parseChoose
  -- stack_tail: sequence * (comma * sequence) ^ 1 / parseStackTail
  dotStack: sequence * (dot * sequence) ^ 1 / parseDotStack
  -- dotStack: (dot * sequence) ^ 1 / parseDotStack

  -- slices
  slice_with_ops: (slice * op ^ 0) / parseSlices
  slice: step + sub_cycle + polymeter + slow_sequence
  sub_cycle: P"[" * ws * (stack + sequence) * ws * P"]" / parseSubCycle
  polymeter: P"{" * ws * sequence * ws * P"}" * polymeter_steps ^ -1 * ws / parsePolymeter
  slow_sequence: P"<" * ws * sequence * ws * P">" * ws / parseSlowSeq
  polymeter_steps: P"%" * slice

  -- ops
  op: fast + slow + tail + range + replicate + degrade + weight + euclid
  fast: P"*" * slice / parseFast
  slow: P"/" * slice / parseSlow
  tail: P":" * slice / parseTail
  range: P".." * ws * slice / parseRange
  degrade: P"?" * (number ^ -1) / parseDegrade
  replicate: ws * P"!" * (number ^ -1) / parseReplicate
  weight: ws * (P"@" + P"_") * (number ^ -1) / parseWeight
  euclid: P"(" * ws * slice_with_ops * comma * slice_with_ops * ws * comma ^ -1 * slice_with_ops ^ -1 * ws * P")" / parseEuclid
}

grammar = Ct C grammar

--- Parse takes a string of mini code and returns an AST
-- @tparam string string of mini-notation
-- @treturn table table of AST nodes
parse = (string) -> grammar\match(string)[2]

return { :parse }