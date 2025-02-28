local fm = require "fullmoon"
local uti = require "utils"
local dbm = require "db"

fm.setTemplate({"/views/", tmpl = "fmt"})


fm.setRoute({"/t(/)", "/tags(/)"}, function(r)
  return fm.serveContent("list_tags")
end)

fm.setRoute({"/t/:tag", "/tags/:tag"}, function(r)
  local s = uti.load_settings()
  return fm.serveContent("tags", {tag = r.params.tag, 
                                  offset = (r.params.offset or s.offset),
                                  limit = (r.params.limit or s.limit)})
end)

local function parse_metadata_filters(r)
  local all_keys = dbm.get_metadata_keys()
  local selected = {}
  
  for i, k in ipairs(all_keys) do
    local p = r.params[k]
    if p ~= nil then
      selected[k] = {}
      for j, value in ipairs(p) do
        selected[k][#selected[k]+ 1] = value
      end
    end
  end
  return selected
end

fm.setRoute("/table", function(r)
  local selected = parse_metadata_filters(r)
  local table_data = dbm.filter_pdfs(selected)
  return fm.serveContent("partial/table", {table_data = table_data, table_header = dbm.get_metadata_keys()})
end)

fm.setRoute({"/p(/)", "/pdfs(/)"}, function(r)
  local selected = parse_metadata_filters(r)
  local table_data = dbm.filter_pdfs(selected)
  return fm.serveContent("list_pdfs", {table_data = table_data, selected = selected})
end)

fm.setRoute({"/p/*path/:pdf", "/pdfs/*path/:pdf"}, function(r)
  local s = uti.load_settings()
  return fm.serveContent("pdfs", {path = r.params.path,
                                  pdf = r.params.pdf,
                                  fullpath = r.params.path .. "/" .. r.params.pdf,
                                  offset = (r.params.offset or s.offset),
                                  limit = (r.params.offset or s.limit)})
end)


fm.setRoute(fm.GET"/settings(/)", function(r)
  return fm.serveContent("settings", {settings = uti.load_settings()})
end)

fm.setRoute(fm.POST"/settings/:settings", function(r)
  -- do something!
end)

-- General
fm.setRoute("/", fm.serveContent("index"))
fm.setRoute("/static/*", fm.serveAsset) 
fm.setRoute("/css/*", "/static/css/*")
fm.setRoute("/img/*", "/static/img/*")
fm.setRoute("/js/*", "/static/js/*")

return fm
