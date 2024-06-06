local lpeg = require "lpeg"
local P, S, V, R, C, Ct = lpeg.P, lpeg.S, lpeg.V, lpeg.R, lpeg.C, lpeg.Ct
local reduce = require("modal.utils").reduce
local filter = require("modal.utils").filter
local map = require("modal.utils").map
local log = require "modal.log"

local ast_to_src = require "modal.ast_to_src"
local mpp = require("metalua.pprint").print

local sequence = V "sequence"
local slice = V "slice"
local sub_cycle = V "sub_cycle"
local polymeter = V "polymeter"
local slow_sequence = V "slow_sequence"
local polymeter_steps = V "polymeter_steps"
local stack = V "stack"
local mini = V "mini"
local op = V "op"
local fast = V "fast"
local slow = V "slow"
local replicate = V "replicate"
local degrade = V "degrade"
local weight = V "weight"
local euclid = V "euclid"
local tail = V "tail"
local range = V "range"
local list = V "list"
local dollar = V "dollar"
local tailop = V "tailop"
local expr = V "expr"
local ret = V "ret"
local set = V "set"
local stat = V "stat"

return function(M, top_level)
   local Id = function(a)
      return { tag = "Id", a }
   end

   local Table = function(a)
      return { tag = "Table", unpack(a) }
   end

   local Str = function(a)
      return { tag = "String", a }
   end

   local Num = function(a)
      return { tag = "Number", a }
   end

   local function check_one(elem, T)
      if T[1] == "Int" then
         if not tonumber(elem[1]) then
            log.warn(string.format("Can not match type %s to Int", type(elem[1])))
            return false
         end
      end
      return true
   end

   local function convert_one(elem, T)
      if T.constructor == "Pattern" then
         return { tag = "Call", Id "pure", elem }
      else
         return elem
      end
   end

   local typecheck = function(name, args)
      local types = M.t[name] -- infer types maybe
      if not types then
         return true, args
      end
      for i = 1, #args do
         if not check_one(args[i], types.T[i]) then
            return false, {}
         end
         args[i] = convert_one(args[i], types.T[i])
      end
      return true, args
   end

   local Call = function(name, ...)
      return { tag = "Call", Id(name), ... }
   end

   local tCall = function(name, ...)
      local ok, args = typecheck(name, { ... })
      if ok then
         return { tag = "Call", Id(name), unpack(args) }
      else
         error()
      end
   end

   local id = function(x)
      return x
   end

   local purify = function(v)
      if type(v) ~= "table" then
         return v
      end
      if v.tag ~= "Call" and v.tag ~= "Id" then
         return Call("pure", v)
      end
      return v
   end

   local string2id = function(v)
      if v.tag == "String" then
         v.tag = "Id"
      end
      return v
   end

   local seed = -1
   local ws = S " \n\r\t" ^ 0
   local comma = ws * P "," * ws
   -- pipe = ws * P("|") * ws
   -- dot = ws * P(".") * ws

   local pNumber = function(num)
      return { tag = "Number", tonumber(num) }
   end

   local parseStep = function(chars)
      if tonumber(chars) then
         return { tag = "Number", tonumber(chars) }
      end
      if string.sub(chars, 0, 1) == "'" then
         return { tag = "Id", chars:sub(2, #chars) }
      end
      return { tag = "String", chars }
   end

   local resolvetails = function(args)
      local fname = table.remove(args, 1)[1]
      local params = filter(function(a)
         return type(a) ~= "function"
      end, args)
      local tails = filter(function(a)
         return type(a) == "function"
      end, args)
      -- local main = { tag = "Call", fname, unpack(params) }
      local main = tCall(fname, unpack(params))
      for i = 1, #tails do
         main = tails[i](main)
      end
      return main
   end

   local step_char = R("09", "AZ", "az") + P "'" + P "-" + P "." + P "^" + P "_" + P "~" / id
   local tidalop = S "|+-*/^%><" ^ 2 / id
   local step = ws * (((step_char ^ 1) + P "+" + P "-" + P "*" + P "/" + P "%") / parseStep) * ws
   local minus = P "-"
   local plus = P "+"
   local zero = P "0"
   local digit = R "09"
   local decimal_point = P "."
   local digit1_9 = R "19"
   local e = S "eE"
   local int = zero + (digit1_9 * digit ^ 0)
   local exp = e * (minus + plus) ^ -1 * digit ^ 1
   local frac = decimal_point * digit ^ 1
   local number = (minus ^ -1 * int * frac ^ -1 * exp ^ -1) / pNumber

   local pFast = function(a)
      return function(x)
         return Call("fast", a, x)
      end
   end

   local pSlow = function(a)
      return function(x)
         return Call("slow", a, x)
      end
   end

   local pDegrade = function(a)
      if a == "?" then
         a = Num(0.5)
      end
      return function(x)
         seed = seed + 1
         return Call("degradeBy", a, x)
      end
   end

   local pTail = function(b)
      return function(a)
         return Call("concat", a, purify(b))
      end
   end

   local pRange = function(s)
      return function(x)
         return Call("iota", x, s)
      end
   end

   local pEuclid = function(p, s, r)
      r = r and r or Num(0)
      return function(x)
         return Call("euclid", p, s, r, x)
      end
   end

   local pWeight = function(a)
      return function(x)
         x.weight = (x.weight or 1) + (tonumber(a) or 2) - 1
         return x
      end
   end

   local pReplicate = function(a)
      return function(x)
         x.reps = (x.reps or 1) + (tonumber(a) or 2) - 1
         return x
      end
   end

   local function resolvereps(ast)
      local res = {}
      for _, node in pairs(ast) do
         if node.reps then
            local reps = node.reps
            for _ = 1, reps do
               node.reps = nil
               res[#res + 1] = node
            end
         else
            res[#res + 1] = node
         end
      end
      return res
   end

   local pSlices = function(sli, ...)
      sli = purify(sli)
      local ops = { ... }
      sli.reps = 1
      sli.weight = 1

      for i = 1, #ops do
         sli = ops[i](sli)
      end
      return sli
   end

   local pSeq = function(...)
      local args = { ... }
      args = resolvereps(args)
      return args, false
   end

   local pStack = function(...)
      local args = { ... }
      args = resolvereps(args)
      return args, true
   end

   local opsymb = {
      ["+"] = { "add", true },
      ["-"] = { "sub", true },
      ["*"] = { "mul", true },
      ["/"] = { "div", true },
      ["^"] = { "pow", true },
      ["%"] = { "mod", true },
      ["."] = { "pipe", false }, -- TODO: proper expr and application
   }

   local function is_op(a)
      return opsymb[a]
   end

   local function pDollar(...)
      local args = { ... }
      if #args == 1 then
         return args
      end
      return resolvetails(args)
   end

   local function pList(...)
      local args = { ... }
      if #args == 1 then
         return args
      elseif #args == 3 then
         if is_op(args[2][1]) then
            local opname, is_native = opsymb[args[2][1]][1], opsymb[args[2][1]][2]
            table.remove(args, 2)
            if is_native then
               return { tag = "Op", opname, unpack(args) }
            else
               -- TODO: check??
               return Call(opname, unpack(map(string2id, args)))
            end
         elseif is_op(args[1][1]) then
            local opname = opsymb[args[1][1]]
            table.remove(args, 1)
            return { tag = "Op", opname, unpack(args) }
         end
      end
      return resolvetails(args)
   end

   local pTailop = function(...)
      local args = { ... }
      local opsymb = table.remove(args, 1)
      args = pDollar(unpack(args))
      return function(x)
         return { tag = "Call", { tag = "Index", Id "op", Str(opsymb) }, x, args }
      end
   end

   local use_timecat = function(args)
      local addWeight = function(a, b)
         b = b.weight and b.weight or 1
         return a + b
      end
      local weightSum = reduce(addWeight, 0, args)
      if weightSum > #args then
         return true
      end
   end

   local resolveweight = function(args)
      local addWeight = function(a, b)
         return a + (b.weight and b.weight or 1)
      end
      local weightSum = reduce(addWeight, 0, args)
      local acc = {}
      for _, v in ipairs(args) do
         acc[#acc + 1] = Num(v.weight) or Num(1)
         -- acc[#acc+1] = purify(v)
         acc[#acc + 1] = v
      end
      -- return { tag = "Call", Id "timecat", Table(acc) }, weightSum
      return Call("timecat", Table(acc)), weightSum
   end

   local pSubCycle = function(args, isStack)
      if isStack then
         -- return { tag = "Call", Id "stack", Table(args) }
         return Call("stack", Table(args))
      else
         if use_timecat(args) then
            local res = resolveweight(args)
            return res
         else
            -- return { tag = "Call", Id "fastcat", Table(args) }
            return Call("fastcat", Table(args))
         end
      end
   end

   local pPolymeter = function(...)
      local args = { ... }
      -- HACK: where bools form?????
      args = filter(function(s)
         return type(s) ~= "boolean"
      end, args)
      local steps = table.remove(args, #args)
      if steps == -1 then
         steps = Num(#args[1])
      end
      -- TODO: into stack, proper stack with sequence
      local function f(s)
         return Call("fastcat", Table(s))
      end
      args = map(f, args)
      return Call("polymeter", steps, Table(args))
   end

   local pSlowSeq = function(args, _)
      if use_timecat(args) then
         local tab, weightSum = resolveweight(args)
         return Call("slow", Num(weightSum), tab)
      else
         return Call("slowcat", Table(args))
      end
   end

   -- TODO: weight in polymeter
   -- TODO: to fraction ?
   -- TODO:  code blocks

   local function pRoot(...)
      local stats = { ... }
      for i, a in ipairs(stats) do
         stats[i] = a
      end
      stats.tag = "Chunk"
      return stats
   end

   local function pRet(a)
      return { tag = "Return", a }
   end

   local function pSet(lhs, rhs)
      lhs.tag = "Id"
      return { tag = "Set", { lhs }, { rhs } }
   end

   local function pStat(...)
      local args = { ... }
      return pRet(resolvetails(args))
   end

   local semi = P ";" ^ -1
   local grammar = {
      "root",
      root = ((set + ret) * semi) ^ 1 / pRoot,
      set = step * P "=" * expr / pSet,
      ret = (list + mini + dollar) / pRet,
      list = P "(" * ws * expr ^ 0 * ws * P ")" / pList,
      dollar = S "$>" * ws * expr ^ 0 * ws / pDollar,
      --- HACK:::::::::::::::::::
      expr = ws * (step + list + mini + dollar + tailop) * ws,
      sequence = (mini ^ 1) / pSeq,
      stack = mini * (comma * mini) ^ 1 / pStack,
      -- choose = sequence * (pipe * sequence) ^ 1 / parseChoose,
      -- dotStack = sequence * (dot * sequence) ^ 1 / parseDotStack,
      -- tailop = P("#") * ws * step * ws * mini * ws / pTailop,
      tailop = tidalop * ws * step * ws * mini * ws / pTailop,
      mini = (slice * op ^ 0) / pSlices,
      slice = step + sub_cycle + polymeter + slow_sequence,
      sub_cycle = P "[" * ws * (stack + sequence) * ws * P "]" / pSubCycle,
      slow_sequence = P "<" * ws * sequence * ws * P ">" / pSlowSeq,
      polymeter = P "{" * ws * sequence * (comma * sequence) ^ 0 * ws * P "}" * polymeter_steps * ws / pPolymeter,
      polymeter_steps = (P "%" * slice) ^ -1 / function(s)
         return (s ~= "") and s or -1
      end,
      op = fast + slow + tail + range + replicate + degrade + weight + euclid,
      fast = P "*" * slice / pFast,
      slow = P "/" * slice / pSlow,
      tail = P ":" * slice / pTail,
      range = P ".." * ws * slice / pRange,
      degrade = P "?" * (number ^ -1) / pDegrade,
      replicate = ws * P "!" * (number ^ -1) / pReplicate,
      weight = ws * (P "@" + P "_") * (number ^ -1) / pWeight,
      euclid = P "(" * ws * mini * comma * mini * ws * comma ^ -1 * mini ^ -1 * ws * P ")" / pEuclid,
   }

   if top_level then
      stat = ws * expr * (expr - S "=") * expr ^ 0 * ws / pStat
      grammar.root = ((stat + set + ret) * semi) ^ 1 / pRoot
   else
      grammar.root = ((set + ret) * semi) ^ 1 / pRoot
   end

   local rules = Ct(C(grammar))

   local read = function(str)
      return rules:match(str)[2]
   end

   return function(src)
      local ok, res, ast, f
      ok, ast = pcall(read, src)
      if not ok then
         return ast, false
      end
      -- mpp(ast)
      local lua_src = ast_to_src(ast)
      ok, f = pcall(loadstring, lua_src)
      if not ok then
         return f, false
      end
      f = setfenv(f, M)
      ok, res = pcall(f)
      return res, ok
   end, function(src)
      local ok, ast
      ok, ast = pcall(read, src)
      if not ok then
         return ast, false
      end

      local lua_src = ast_to_src(ast)
      return lua_src, ok
   end
end
