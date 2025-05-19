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

-- Reused functions

local pdf_page_handler = function(template)
  return function(r)
  local s = uti.load_settings()
  local pdf = r.params.pdf .. '.pdf'
  local fullpath = r.params.path .. '/' .. pdf
  local low = r.params.low or 1
  local high = r.params.high or s.max_pages
  if r.params.low ~= nil or r.params.high ~= nil then
      pages = dbm.load_images_by_page_range(fullpath, low, high)
  else
  pages = dbm.load_images_by_pdf(fullpath,
                                       r.params.limit or s.max_pages)
  end
  if #pages < tonumber(high) - tonumber(low) then
    high = #pages + tonumber(low)
  end
  return fm.serveContent(template, {fullpath = fullpath,
                                  pdf = pdf,
                                  low = low,
                                  high = high,
                                  pages = pages})
  end

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
-- Fetch summary pages of each
--

fm.setRoute({"/v/all", "/views/all"}, function(r)
  local s = uti.load_settings()
  return fm.serveContent("views", {current_view=s.default_view})
end)

fm.setRoute({"/v/set", "/views/set", method="POST"}, function(r)
  local s = uti.load_settings()
  local view_name = r.params.view or s.default_view
  if r.params.view == nil then
    local code = 304
  else
    local code = 201
  end
  return fm.serveRedirect(code, "/views/" .. view_name)
end)


fm.setRoute({"/t/all", "/tags/all"}, function(r)
  local table_header = {"tag", "count"}
  return fm.serveContent("list_tags", {table_data = dbm.get_all_tags(),
                                       table_header = table_header,
                                       show_id = false})
end)

fm.setRoute({"/p/all", "/pdfs/all"}, function(r)
  local table_data = dbm.get_all_pdfs()
  return fm.serveContent("list_pdfs", {table_data = table_data})
end)

-- Fetch specific of each
fm.setRoute({"/t(/)", "/tags(/)"}, function(r)
  local s = uti.load_settings()
  local selected = parse_metadata_filters(r)
  local table_data = dbm.filter_tags(selected)
  return fm.serveContent("list_tags", {table_data = table_data,
                                       table_header=table_header,
                                       selected = selected})
end)

fm.setRoute({"/p(/)", "/pdfs(/)"}, function(r)
  local selected = parse_metadata_filters(r)
  local table_data = dbm.filter_metadata(selected)
  local table_header = dbm.get_metadata_keys()
  return fm.serveContent("list_pdfs", {table_data = table_data,
                                       table_header=table_header,
                                       selected = selected})
end)

fm.setRoute({"/t/:tag(/)", "/tags/:tag(/)"}, function(r)
  local s = uti.load_settings()
  local limit = r.params.limit or s.max_pages
  local pages = dbm.load_images_by_tag(r.params.tag,
                                       limit)
  if tonumber(limit) > #pages then
    limit = #pages
  end
  return fm.serveContent("tags", {tag = r.params.tag,
                                  limit = limit,
                                  pages = pages})
end)


fm.setRoute({"/v(/*path)/:view", "/views(/*path)/:view"}, function(r)
  local path = r.params.path or ""
  local view_name = r.params.view
  local view = path .. "/" .. view_name
  print("Current view :", view)
  return fm.serveRedirect("/v/all")
end)

fm.setRoute({"/p/*path/:pdf.pdf", "/pdfs/*path/:pdf.pdf"}, pdf_page_handler('pdfs'))
fm.setRoute({"/data/p/*path/:pdf.pdf", "/data/pdfs/*path/:pdf.pdf"}, pdf_page_handler('partial/pages'))

fm.setRoute({"/p/*path/:pdf.pdf/pages/(:low[%d])-(:high[%d])",
             "/pdfs/*path/:pdf.pdf/pages/(:low[%d])-(:high[%d])"}, pdf_page_handler('pdfs'))

fm.setRoute({"/raw/p/*path/:pdf.pdf/pages/(:low[%d])-(:high[%d])",
             "/raw/pdfs/*path/:pdf.pdf/pages/(:low[%d])-(:high[%d])"}, pdf_page_handler('partial/pages'))

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
