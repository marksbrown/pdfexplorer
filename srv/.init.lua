-- DB Explorer
local fm = require "api"

local db = fm.makeStorage("compsci.db")

--Load pdf pages
local offset = 0  -- TODO how is this altered by the user?

--Config
local max_pages = 5
local links = {home = "/",
               tags = '/tags/',
               pdfs = '/pdfs/',
               statistics = '/stats/'}

fm.setTemplateVar("title", "PDF Explorer")
fm.setTemplateVar("links", links)
fm.setTemplateVar("lang", "en_gb")
fm.setTemplateVar("siteurl", "")

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


fm.setTemplateVar("load_images_by_pdf", function(pdf)
  local cmd = [[
  select * from
  (select pages.id, page, png from pages
  where pages.id = (?) 
  order by pages.page)
  limit (?), (?);
  ]]
return db:fetchAll(cmd, pdf, offset, offset + max_pages)
end)

fm.setTemplateVar("load_images_by_tag", function(tag)
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

fm.setTemplateVar("get_all_pdfs", function()
  local cmd = [[
  SELECT id, metadata
  FROM pdfs
  ORDER BY id
  DESC;]]
  return db:fetchAll(cmd)
end)

fm.setTemplateVar("get_all_tags", function()
  local cmd = [[
  SELECT tag, COUNT(*) 
  FROM pagetags 
  GROUP BY tag
  ORDER BY COUNT(*)
  DESC;]]
  return db:fetchAll(cmd)
end)

fm.run()
