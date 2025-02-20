local fm = require "fullmoon"

fm.setTemplate({"/views/", tmpl = "fmt"})

fm.setRoute({"/t(/)", "/tags(/)"}, function(r)
  return fm.serveContent("list_tags")
end)

fm.setRoute({"/t/:tag", "/tags/:tag"}, function(r)
  return fm.serveContent("tags", {tag = r.params.tag, 
                                  offset = (r.params.offset or 0),
                                  limit = (r.params.limit or -1)})
end)

fm.setRoute({"/p(/)", "/pdfs(/)"}, function(r)
  return fm.serveContent("list_pdfs")
end)

fm.setRoute({"/p/*path/:pdf", "/pdfs/*path/:pdf"}, function(r)
  return fm.serveContent("pdfs", {pdf = r.params.path .. "/" .. r.params.pdf,
                                  offset = (r.params.offset or 0),
                                  limit = (r.params.offset or -1)})
end)

-- Statistics
fm.setRoute({"/s(/)", "/stats(/)"}, fm.serveContent("statistics")) 
fm.setRoute({"/s/t(/)", "/s/tags(/)"}, function (r) return "Statistics relating to all tags" end)
fm.setRoute({"/s/p(/)", "/s/pdfs(/)"}, function (r) return "Statistics relating to all pdfs" end)
fm.setRoute({"/s/t/:tag", "/s/tags/:tag"}, function (r) return "Statistics relating to " ..r.params.tag end)
fm.setRoute({"/s/p/:pdf", "/s/pdfs/:pdf"}, function (r) return "Statistics relating to " ..r.params.pdf end)

-- General
fm.setRoute("/", fm.serveContent("index"))
fm.setRoute("/static/*", fm.serveAsset) 
fm.setRoute("/css/*", "/static/css/*")
fm.setRoute("/img/*", "/static/img/*")

return fm
