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

return m
