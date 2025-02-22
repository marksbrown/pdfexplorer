-- DB Explorer
local fm = require "api"

local db = fm.makeStorage("compsci.db")

--Config
local links = {home = "/",
               tags = '/tags/',
               pdfs = '/pdfs/',
               statistics = '/stats/'}

fm.setTemplateVar("title", "PDF Explorer")
fm.setTemplateVar("links", links)
fm.setTemplateVar("lang", "en_gb")
fm.setTemplateVar("siteurl", "")


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

fm.setTemplateVar("get_pdfs_filter", function(key, ...)
  if #arg == 0 then
    return get_all_pdfs()
  end
  local cmd = [[
    select pdfs.id, key, value
    from pdfs, json_tree(pdfs.metadata)
    where key not null
    and key = (?)
    and value in (?);
    ]]
    return fm:fetchAll(cmd, key, arg)
end)

fm.setTemplateVar("get_metadata_keys", function()
  local cmd = [[
    select distinct key
    from pdfs, json_tree(pdfs.metadata)
    where json_tree.type not in ('object')
    order by key ASC;
  ]]
  local raw_data = db:fetchAll(cmd)
  local parsed = {}
  for i, row in ipairs(raw_data) do
    parsed[i] = row.key
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


fm.setTemplateVar("list_pdfs_matching_metadata", function(fullkey, value)
 local cmd = [[
SELECT id
from pdfs
where json(metadata) ->> (?) = (?);
 ]]
 return db:fetchAll(cmd, fullkey, value)
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
