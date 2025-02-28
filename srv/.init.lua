-- DB Explorer
local fm = require "fullmoon"
local uti = require "utils" 

require "api"


local db = assert(fm.makeStorage("compsci.db"))

--Config
local links = {home = "/",
               tags = '/tags/',
               pdfs = '/pdfs/',
               settings = '/settings/'}

local rolecall = {'home', 'pdfs', 'tags', 'settings'}

fm.setTemplateVar("title", "PDF Explorer")
fm.setTemplateVar("links", links)
fm.setTemplateVar("rollcall", rolecall)
fm.setTemplateVar("lang", "en_gb")
fm.setTemplateVar("siteurl", "")

fm.setTemplateVar("uti", uti)  -- make utilities available to templates

local get_all_pdfs = function()
  local cmd = [[
  SELECT id, metadata
  FROM pdfs
  ORDER BY id
  DESC;]]
  local raw_data = db:fetchAll(cmd)
  local parsed = {}
  for k,v in pairs(raw_data) do
    parsed[v.id] = DecodeJson(v.metadata)
  end
  return parsed
end

fm.setTemplateVar("get_all_pdfs", get_all_pdfs)

local get_matching_pdfs = function(key, value)
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
    local raw_data = db:fetchAll(cmd, key, table.unpack(value))
    local parsed = {}
    for k,v in pairs(raw_data) do
      parsed[v.id] = DecodeJson(v.metadata)
    end
    return parsed
end

fm.setTemplateVar("filter_pdfs", function(filter_by)
  if uti.len(filter_by) == 0 then  -- defaults to showing all
    return get_all_pdfs()
  end
  local results = nil
  for mkey, mvalue in pairs(filter_by) do
    local new_result = get_matching_pdfs(mkey, mvalue) 
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
end)

local get_metadata_keys = function()
  local cmd = [[
    select distinct key
    from pdfs, json_tree(pdfs.metadata)
    where json_tree.type not in ('object')
    order by key ASC;
  ]]
  return db:fetchAll(cmd)
end

local _get_header = function()
  local d = get_metadata_keys()
  local p = {}
  for i,k in ipairs(d) do
    p[#p + 1] = k.key
  end
  return p
end

fm.setTemplateVar("header", _get_header()) 

fm.setTemplateVar("get_metadata_values", function(key)
  local cmd = [[
select distinct value
from pdfs, json_tree(pdfs.metadata)
where key not null
and key = (?);
  ]]
  local d = db:fetchAll(cmd, key)
  local parsed = {}
  for i, values in ipairs(d) do
    parsed[#parsed + 1] = values.value
  end
  return parsed
end)

fm.setTemplateVar("get_tag_count", function(tag)
  local d = db:fetchAll([[SELECT count from tags WHERE tag = (?);]], tag)
  if #d == 0 then
    return 0
  else
    return d[1].count
  end
end)

fm.setTemplateVar("list_matching_pdfs", function(pdf)
  local cmd = [[
  [[
  SELECT distinct id
  from pages
  where id
  like (?);
  ]]
return db:fetchAll(cmd, pdf)
end)

fm.setTemplateVar("load_images_by_pdf", function(pdf, offset, max_pages)
  local cmd = [[
  select * from
  (select pages.id, page, png from pages
  where pages.id = (?) 
  order by pages.page)
  limit (?), (?);
  ]]
return db:fetchAll(cmd, pdf, offset, offset + max_pages)
end)

fm.setTemplateVar("load_images_by_tag", function(tag, offset, max_pages)
  local cmd = [[
  SELECT * from (select pages.id, pages.page, png from pages
  join pagetags
  on pages.id == pagetags.id
  and pages.page == pagetags.page
  where pagetags.tag = (?)
  order by pages.id desc)
  limit (?), (?);
  ]]
  return db:fetchAll(cmd, tag, offset, offset + max_pages)
end)

fm.setTemplateVar("pdfs_by_tag", function(tag)
  local cmd = [[
  SELECT id, page FROM pagetags
  WHERE
  tag = (?)
  ORDER BY
  id, page
  ASC; 
  ]]
  return db:fetchAll(cmd, tag)
end)

fm.setTemplateVar("tags_by_pdf", function(pdf)
  local cmd = [[
  SELECT distinct tag
  from pagetags
  where id = (?) 
  order by
  tag asc;
  ]]
  return db:fetchAll(cmd, pdf)
end)

fm.setTemplateVar("tags_by_pdf_and_page", function(pdf, page)
  local cmd = [[
  SELECT distinct tag
  from pagetags
  where id = (?) and page = (?) 
  order by
  tag asc;
  ]]
  return db:fetchAll(cmd, pdf, page)
end)

fm.setTemplateVar("get_all_tags", function(pdf)
  if pdf ~= nil then
    local cmd = [[
  SELECT tag, COUNT(*) as count
  FROM 
  pagetags 
  where pagetags.id = (?)
  GROUP BY tag
  ORDER BY tag
  ASC;]]
  return db:fetchAll(cmd, pdf)
else
  local cmd = [[
  SELECT tag, COUNT(*) as count
  FROM pagetags
  GROUP BY tag
  ORDER BY tag
  ASC;]]
  return db:fetchAll(cmd)
end
end)

fm.run()
