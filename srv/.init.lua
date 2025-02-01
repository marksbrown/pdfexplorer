-- DB Explorer
local fm = require "fullmoon"

local db = fm.makeStorage("compsci.db")
fm.setTemplate({"/views/", tmpl = "fmt"})

local links = {home = "/",
               tags = '/tags/',
               pdfs = '/pdfs/'}

fm.setTemplateVar("links", links)
fm.setTemplateVar("lang", "en_gb")
fm.setTemplateVar("title", "PDF Explorer")
fm.setTemplateVar("siteurl", "")

fm.setTemplateVar("get_tag_count", function(tag)
  local d = db:fetchAll([[SELECT count from tags WHERE tag = (?);]], tag)
  if #d == 0 then
    return 0
  else
    return d[1].count
  end
end)

fm.setTemplateVar("load_images_by_tag", function(tag)
  local cmd = [[
  select pages.id, pages.page, png from pages
  join pagetags
  on pages.id == pagetags.id
  and pages.page == pagetags.page
  where pagetags.tag = (?)
  order by pages.id
  desc
  limit 10;
  ]]
  return db:fetchAll(cmd, tag)
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


fm.setTemplateVar("get_all_tags", function()
  local cmd = [[
  SELECT tag, COUNT(*) 
  FROM pagetags 
  GROUP BY tag
  ORDER BY COUNT(*)
  DESC;]]
  return db:fetchAll(cmd)
end)

fm.setRoute({"/t(/)", "/tags(/)"}, function(r)
  return fm.serveContent("page", {current_page = "tags", tag = ""})
end)

fm.setRoute({"/t/:tag", "/tags/:tag"}, function(r)
  return fm.serveContent("page", {current_page = "tags", tag = r.params.tag})
end)

fm.setRoute("/", fm.serveContent("index", {current_page = "index", name = "Mark"}))
fm.setRoute({"/p/:pdf", "/pdfs/:pdf"}, function(r) return "PDF: "..(r.params.pdf) end)
fm.setRoute("/static/*", fm.serveAsset) 
fm.setRoute("/css/*", "/static/css/*")


fm.run()
