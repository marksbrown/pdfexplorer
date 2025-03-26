local fm = require "fullmoon"
local uti = require "utils"
local dbm = require "db"

fm.setTemplate({"/views/", tmpl = "fmt"})

-- Local utility functions
local function parse_metadata_filters(r)
  local all_keys = dbm.get_metadata_keys()
  local selected = {}
  
  for i, k in ipairs(all_keys) do
    local p = r.params[k]
    selected[k] = {}
    if p ~= nil then
      for j, value in ipairs(p) do
        selected[k][#selected[k]+ 1] = value
      end
    end
  end
  return selected
end

-- Partial Routes for AJAX requests
fm.setRoute("/table/pdfs", function(r)
  local selected = parse_metadata_filters(r)
  return fm.serveContent("partial/table", {table_data = dbm.filter_metadata(selected),
                                           table_header = dbm.get_metadata_keys(),
                                           show_id = true})
end)

fm.setRoute("/table/pdfs/all", function(r)
  return fm.serveContent("partial/table", {table_data = dbm.get_all_pdfs(),
                                           table_header = dbm.get_metadata_keys(),
                                           show_id = true})
end)


fm.setRoute("/table/tags", function(r)
  local selected = parse_metadata_filters(r)
  local table_header = {"tag", "count"}
  return fm.serveContent("partial/table", {table_data = dbm.filter_tags(selected),
                                           table_header = table_header,
                                           show_id = false})
end)

fm.setRoute("/table/tags/all", function(r)
  local table_header = {"tag", "count"}
  return fm.serveContent("partial/table", {table_data = dbm.get_all_tags(),
                                           table_header = table_header,
                                           show_id = false})
end)

-- Full Routes
fm.setRoute({"/data/t/all", "/data/tags/all"}, function(r)
  local table_header = {"tag", "count"}
  return fm.serveContent("list_tags", {table_data = dbm.get_all_tags(),
                                       table_header = table_header,
                                       show_id = false})
end)

fm.setRoute({"/data/p/all", "/data/pdfs/all"}, function(r)
  local table_data = dbm.get_all_pdfs()
  return fm.serveContent("list_pdfs", {table_data = table_data})
end)

fm.setRoute({"/data/t/:tag", "/data/tags/:tag"}, function(r)
  local s = uti.load_settings()
  local selected = parse_metadata_filters(r)
  local table_data = dbm.filter_tags(selected)
  return fm.serveContent("list_tags", {table_data = table_data,
                                       table_header=table_header,
                                       selected = selected})
end)

fm.setRoute({"/data/p(/)", "/data/pdfs(/)"}, function(r)
  local selected = parse_metadata_filters(r)
  local table_data = dbm.filter_metadata(selected)
  local table_header = dbm.get_metadata_keys()
  return fm.serveContent("list_pdfs", {table_data = table_data,
                                       table_header=table_header,
                                       selected = selected})
end)

fm.setRoute({"/t/:tag", "/tags/:tag"}, function(r)
  local s = uti.load_settings()
  return fm.serveContent("tags", {tag = r.params.tag,
                                  offset = (r.params.offset or s.offset),
                                  limit = (r.params.offset or s.limit)})
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

-- General
fm.setRoute("/", fm.serveContent("index"))
fm.setRoute("/static/*", fm.serveAsset) 
fm.setRoute("/css/*", "/static/css/*")
fm.setRoute("/img/*", "/static/img/*")
fm.setRoute("/js/*", "/static/js/*")

return fm
