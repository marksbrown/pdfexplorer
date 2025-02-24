local fm = require "fullmoon"

local load_settings = function()
  fd = assert(unix.open('/zip/defaults.json', unix.O_RDONLY))
  local params = assert(DecodeJson(unix.read(fd)))
  unix.close(fd)
  return params
end

fm.setTemplate({"/views/", tmpl = "fmt"})

fm.setRoute({"/t(/)", "/tags(/)"}, function(r)
  return fm.serveContent("list_tags")
end)

fm.setRoute({"/t/:tag", "/tags/:tag"}, function(r)
  local s = load_settings()
  return fm.serveContent("tags", {tag = r.params.tag, 
                                  offset = (r.params.offset or s.offset),
                                  limit = (r.params.limit or s.limit)})
end)

fm.setRoute({"/p(/)", "/pdfs(/)"}, function(r)
  return fm.serveContent("list_pdfs")
end)

fm.setRoute({"/p/*path/:pdf", "/pdfs/*path/:pdf"}, function(r)
  local s = load_settings()
  return fm.serveContent("pdfs", {pdf = r.params.path .. "/" .. r.params.pdf,
                                  offset = (r.params.offset or s.offset),
                                  limit = (r.params.offset or s.limit)})
end)


fm.setRoute(fm.GET"/settings(/)", function(r)
  return fm.serveContent("settings", {settings = load_settings()})
end)

fm.setRoute(fm.POST"/settings/:settings", function(r)
  -- do something!
end)

-- General
fm.setRoute("/", fm.serveContent("index"))
fm.setRoute("/static/*", fm.serveAsset) 
fm.setRoute("/css/*", "/static/css/*")
fm.setRoute("/img/*", "/static/img/*")

return fm
