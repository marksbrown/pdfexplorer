local fm = require "fullmoon"
local uti = require "utils"

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

fm.setRoute({"/p(/)", "/pdfs(/)"}, function(r)
  --TODO(?) replace this with db call listing *aggregate* union of all metadata keys
  all_keys = {"date", "exam-board", "part", "level"}
  selected = {}
  
  for i, k in ipairs(all_keys) do
    local p = r.params[k]
    if p ~= nil then
      selected[k] = {}
      for j, value in ipairs(p) do
        selected[k][#selected[k]+ 1] = value
      end
    end
  end

  if uti.len(selected) == 0 then
    selected = nil
  end

  return fm.serveContent("list_pdfs", {selected = selected})
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
