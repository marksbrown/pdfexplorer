local fm = require "fullmoon"

local m = {}



-- linear search
function m.value_in_arr(value, arr)
  for i,v in ipairs(arr) do
    if value == v then
      return true
    end
  end
  return false
end


function m.key_in_tbl(key, tbl)
  for k,v in pairs(tbl) do
    if k==key then
      return true
    end
  end
  return false
end

function m.value_in_array(key, tbl)
  return m.value_in_arr(key, tbl)
end

function m.key_in_table(key, tbl)
  return m.key_in_tbl(key, tbl)
end

function m.get(tbl, key, default)
   if m.key_in_tbl(key, tbl) then
     return tbl[key]
   else
     return default
   end
end

function m.dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. m.dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

function m.union(f, s)
  u = {}
  for k,v in pairs(s) do
    if f[k] ~= nil then
      u[k] = f[k]
    end
  end
  return u
end

function m.set_difference(f, s)
  --all elements in f and not in s
 r = {}
 for i,v in ipairs(f) do
  if not m.value_in_arr(v, s) then
    r[#r + 1] = v
  end
 end
 return r
end

function m.len(tbl)
  if tbl == nil then
    return 0
  end
  local c = 0
  for _,v in pairs(tbl) do
    c = c + 1
  end
  return c
end

function m.load_settings()
  fd = assert(unix.open('/zip/defaults.json', unix.O_RDONLY))
  local params = assert(DecodeJson(unix.read(fd)))
  unix.close(fd)
  return params
end

function m.concat(x, ...) 
  for k, r in ipairs({...}) do
    for i, v in ipairs(r) do
      x[#x + 1] = v
    end
  end
  return x
end

function m.sorted(arr, ascending, key)
  local key = key or function(x) return x end
  local ascending = ascending or true
  if #arr <= 1 then
    return arr
  end
  local mid = #arr // 2
  local pivot = arr[mid]
  local low = {}
  local middle = {}
  local high = {}
  for i, k in ipairs(arr) do
    if key(k) < key(pivot) then
      low[#low + 1] = k
    elseif key(k) == key(pivot) then
      middle[#middle + 1] = pivot
    else
      high[#high + 1] = k
    end
  end
  local r = m.concat(m.sorted(low, ascending, key), middle, m.sorted(high, ascending, key))
  return r
end

local t = {}  -- testing
function t.test_sorted()
  local data = {{{1,2}, {3,4}}, {{}, {1,2,3,4}}, {{}, {}}}
  for k, test_data in ipairs(data) do
    print("concat :: ", m.dump(test_data), m.dump(m.concat(test_data)))
  end
  local data = {{'a', 'd', 'b', 'c'}, {1,3,2,4}, {1,1,1,1}, {1}, {}}
  for k, test_data in ipairs(data) do
    print("sorted:: ", m.dump(test_data), m.dump(m.sorted(test_data)))
  end
  
  local test_data =  {"az", "by", "cx"}
  print("sorted (with key)::", m.dump(m.sorted(test_data, true, function(x) return string.sub(x, 2, 2) end)))
end

t.test_sorted()

return m
