-- SQLite DB management
local fm = require "fullmoon"
local uti = require "utils"

local dbm = {}

dbm.load_db = function()
  -- 1. load settings
  -- 2. get name of DB
  -- 3. return
  settings = uti.load_settings()
  name = settings["database"]["name"]
  return assert(fm.makeStorage(name))
end

dbm.db = dbm.load_db()

dbm.get_all_pdfs = function()
  local cmd = [[
  SELECT id, metadata
  FROM pdfs
  ORDER BY id
  DESC;]]
  local raw_data = dbm.db:fetchAll(cmd)
  local parsed = {}
  for k,v in pairs(raw_data) do
    parsed[v.id] = DecodeJson(v.metadata)
  end
  return parsed
end

dbm.get_matching_pdfs = function(key, value)
  -- value can be str or tbl
  -- thus need to alter cmd to fit unknown length of value
  local in_clause = string.rep("?, ", #value):sub(1, -3) -- magic
  local cmd = [[
    select pdfs.id, pdfs.metadata
    from pdfs, json_tree(pdfs.metadata)
    where key not null
    and key = (?)
    and value in (]]
    ..
    in_clause
    ..[[)
    order by pdfs.id
    DESC;
    ]]
    local raw_data = dbm.db:fetchAll(cmd, key, table.unpack(value))
    local parsed = {}
    for k,v in pairs(raw_data) do
      parsed[v.id] = DecodeJson(v.metadata)
    end
    return parsed
end

dbm.get_matching_tags = function(key, value)
  local cmd = [[
  select tags.tag, count
  from tags
  join pagetags
  on pagetags.tag = tags.tag
  where (?)
  like (?)
  group by tags.tag;
  ]]
  return dbm.db:fetchAll(cmd, key, value)
end

dbm.get_metadata_keys = function()
  local cmd = [[
    select distinct key
    from pdfs, json_tree(pdfs.metadata)
    where json_tree.type not in ('object')
    order by key ASC;
  ]]
  local d = dbm.db:fetchAll(cmd)
  local parsed = {}
  for k,v in ipairs(d) do
    parsed[#parsed + 1] = v.key
  end
  return parsed
end

dbm.get_metadata_values = function(key)
  local cmd = [[
select distinct value
from pdfs, json_tree(pdfs.metadata)
where key not null
and key = (?);
  ]]
  local d = dbm.db:fetchAll(cmd, key)
  local parsed = {}
  for i, values in ipairs(d) do
    parsed[#parsed + 1] = values.value
  end
  return parsed
end

dbm.get_tag_count = function(tag)
  local d = dbm.db:fetchAll([[SELECT count from tags WHERE tag = (?);]], tag)
  if #d == 0 then
    return 0
  else
    return d[1].count
  end
end

dbm.list_matching_pdfs = function(pdf)
  local cmd = [[
  [[
  SELECT distinct id
  from pages
  where id
  like (?);
  ]]
return dbm.db:fetchAll(cmd, pdf)
end


dbm.load_images_by_pdf = function(pdf, offset, max_pages)
  local cmd = [[
  select * from
  (select pages.id, page, png from pages
  where pages.id = (?) 
  order by pages.page)
  limit (?), (?);
  ]]
return dbm.db:fetchAll(cmd, pdf, offset, offset + max_pages)
end


dbm.load_images_by_tag = function(tag, offset, max_pages)
  local cmd = [[
  SELECT * from (select pages.id, pages.page, png from pages
  join pagetags
  on pages.id == pagetags.id
  and pages.page == pagetags.page
  where pagetags.tag = (?)
  order by pages.id desc)
  limit (?), (?);
  ]]
  return dbm.db:fetchAll(cmd, tag, offset, offset + max_pages)
end

dbm.pdfs_by_tag = function(tag)
  local cmd = [[
  SELECT id, page FROM pagetags
  WHERE
  tag = (?)
  ORDER BY
  id, page
  ASC; 
  ]]
  return dbm.db:fetchAll(cmd, tag)
end

dbm.tags_by_pdf = function(pdf)
  local cmd = [[
  SELECT distinct tag
  from pagetags
  where id = (?) 
  order by
  tag asc;
  ]]
  return dbm.db:fetchAll(cmd, pdf)
end

dbm.tags_by_pdf_and_page = function(pdf, page)
  local cmd = [[
  SELECT distinct tag
  from pagetags
  where id = (?) and page = (?) 
  order by
  tag asc;
  ]]
  return dbm.db:fetchAll(cmd, pdf, page)
end

dbm.get_all_tags = function(pdf)
  if pdf ~= nil then
    local cmd = [[
  SELECT tag, COUNT(*) as count
  FROM 
  pagetags 
  where pagetags.id = (?)
  GROUP BY tag
  ORDER BY tag
  ASC;]]
  return dbm.db:fetchAll(cmd, pdf)
else
  local cmd = [[
  SELECT tag, COUNT(*) as count
  FROM pagetags
  GROUP BY tag
  ORDER BY tag
  ASC;]]
  return dbm.db:fetchAll(cmd)
end
end

dbm.filter_pdfs = function(filter_by)
  local results = nil
  for mkey, mvalue in pairs(filter_by) do
    local new_result = dbm.get_matching_pdfs(mkey, mvalue) 
    if results == nil then
      results = new_result
    else
      results = uti.union(results, new_result)
      if uti.len(results) == 0 then  -- none matching found
        return results
      end
    end
  end
  return results
end

return dbm
