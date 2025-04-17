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
  local pages = dbm.load_images_by_tag(r.params.tag,
                                       r.params.offset or s.offset,
                                       r.params.limit or s.limit)
  return fm.serveContent("tags", {tag = r.params.tag,
                                  pages = pages})
end)


local pdf_page_handler = function(template)
  return function(r)
  local s = uti.load_settings()
  local pdf = r.params.pdf .. '.pdf'
  local fullpath = r.params.path .. '/' .. pdf
  local pages = dbm.load_images_by_pdf(fullpath,
                                       r.params.offset or s.offset,
                                       r.params.limit or s.limit)
  return fm.serveContent(template, {fullpath = fullpath,
                                  pdf = pdf,
                                  pages = pages})
  end

end

fm.setRoute({"/p/*path/:pdf.pdf", "/pdfs/*path/:pdf.pdf"}, pdf_page_handler('pdfs'))
fm.setRoute({"/raw/p/*path/:pdf.pdf", "/raw/pdfs/*path/:pdf.pdf"}, pdf_page_handler('partial/pages'))

fm.setRoute({"/p/*path/:pdf.pdf/pages/(:low[%d])-(:high[%d])", 
             "/pdfs/*path/:pdf.pdf/pages/(:low[%d])-(:high[%d])"}, function(r)
  local s = uti.load_settings()
  local low = r.params.low or 1
  local high = r.params.high or s.max_pages
  if tonumber(low) > tonumber(high) then
    return "Invalid parameters"
  end
  
  local pdf = r.params.pdf .. '.pdf'
  local fullpath = r.params.path .. '/' .. pdf
  local pages = dbm.load_images_by_page_range(fullpath, low, high)
  
  return fm.serveContent("pdfs", {fullpath = fullpath,
                                  pdf = pdf,
                                  pages = pages})
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
