local fm = require "fullmoon"
local uti = require "utils"
local dbm = require "db"

fm.setTemplate({"/views/", tmpl = "fmt"})

--===== General =====--
fm.setRoute("/", fm.serveContent("index"))
fm.setRoute("/static/*", fm.serveAsset) 
fm.setRoute(fm.GET"/css/*", "/static/css/*")
fm.setRoute(fm.GET"/img/*", "/static/img/*")
fm.setRoute(fm.GET"/js/*", "/static/js/*")

--===== /table/* =====--
fm.setRoute(fm.GET"/table/pdfs", fm.serveRedirect("/table/all/pdfs"))
fm.setRoute(fm.GET"/table/tags", fm.serveRedirect("/table/all/tags"))

local pdf_table = function(filter)
  local filter = filter or 'all'
  assert(dbm.validate_filter(filter))
  local url = {id = fm.makePath("filters/:filter/pdfs", {filter=filter})}
  if filter == 'all' then
  return {data = dbm.get_all_pdfs(),
          header = dbm.get_metadata_keys(),
          records = dbm.get_count_pdfs_by_filter(filter),
          url = url,
          table_id = "table-pdfs",
          show_id = true}
  else
    local data = dbm.get_pdfs_by_filter(filter)
    return {data = data,
            header = dbm.get_metadata_keys(),
            records = dbm.get_count_pdfs_by_filter(filter),
            url = url,
            table_id = "table-pdfs",
            show_id = true}
  end
end

fm.setRoute(fm.GET"/table/:filter/pdfs", function(r)
  return fm.serveContent("partial/table", pdf_table(r.params.filter))
end)

fm.setRoute(fm.GET"/table/:filter/pdfs/json", function(r)
  return fm.serveContent("json", pdf_table(r.params.filter))
end)

local tag_table = function(filter)
  local filter = filter or 'all'
  assert(dbm.validate_filter(filter))
  local url = {tag = "filters/" .. filter .. "/tags"}
  local header = {"tag", "count"}
  if filter == 'all' then
  return {data = dbm.get_all_tags(),
          header = header,
          records = dbm.count_tags("all"),
          table_id = "table_tags",
          url = url,
          show_id = false}
  else
    return {data = dbm.get_tags_by_filter(filter),
            header = header,
            url = url,
            records = dbm.count_tags(filter),
            table_id = "table_tags",
            show_id = false}
  end
end

fm.setRoute(fm.GET"/table/:filter/tags", function(r)
  return fm.serveContent("partial/table", tag_table(r.params.filter))
end)

fm.setRoute(fm.GET"/table/:filter/tags/json", function(r)
  return fm.serveContent("json", tag_table(r.params.filter))
end)

local filter_table = function()
  local actions = {"modify", "delete"}
  local data = dbm.get_all_filters()
  return {data = data,
          header = {"name", "modify", "delete"},
          records = dbm.count_filters(),
          table_id = "table_filters",
          show_id = false}
end

fm.setRoute(fm.GET"/table/filters", function(r)
  return fm.serveContent("tables/filters", filter_table())
end)

fm.setRoute(fm.GET"/table/filters/json", function(r)
  return fm.serveContent("json", filter_table())
end)

--===== /filters/* =====--
local view_filters_handler = function(template)
  return function(r)
    filter = r.params.filter
    assert(dbm.validate_filter(filter))
    local form_data = {}
    for i, key in ipairs(dbm.get_metadata_keys()) do
      all_values = dbm.get_metadata_values(key, "all")
      selected_values = dbm.get_metadata_values(key, filter)

      form_data[key] = {}
      for i, value in ipairs(all_values) do
        form_data[key][value] = uti.value_in_arr(value, selected_values)
      end
    end
    return fm.serveContent(template, {filter = filter,
                                     filters = filter_table(),
                                     form_data = form_data,
                                     pdfs = pdf_table(filter),
                                     tags = tag_table(filter)})
  end
end

fm.setRoute(fm.GET"/f", fm.serveRedirect("/f/all"))
fm.setRoute({"/filters", "/filters/create", "/filters/:filter/delete", method="GET"}, fm.serveRedirect("/filters/all"))
fm.setRoute({"/f/:filter", "/filters/:filter", method="GET"}, view_filters_handler("filters"))
fm.setRoute({"/f/:filter/json", "/filters/:filter/json", method="GET"}, view_filters_handler("json"))

local parse_metadata_filters = function(r)
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

--create (POST)
local filters_create_handler = function(method)
  return function(r)
  local new_filter = r.params.new_filter
  if dbm.validate_filter(new_filter) then
    print("Filter already exists!")
    return fm.serveResponse("409", "Filter already exists with name : " .. new_filter)
  elseif new_filter == "all" or new_filter == "new" or new_filter == "create" then
      return fm.serveResponse("400", "Invalid filter name : " .. new_filter)
  end

  local metadata = parse_metadata_filters(r)
  assert(dbm.create_new_filter(new_filter, metadata))
  return fm.serveRedirect("/filters/"..new_filter)
end
end

fm.setRoute({"/f", "/filters", "/f/create", "/filters/create", method="POST"}, filters_create_handler("POST"))

--modify (PUT)
local filters_modify_handler = function(method)
  return function(r)
  local filter = r.params.filter
  local filter = r.params.existing_filter or r.params.filter
  local metadata = parse_metadata_filters(r)
  if dbm.validate_filter(filter) then
      dbm.delete_filter(filter)
      assert(dbm.create_new_filter(filter, metadata))
      return fm.serveRedirect()
  else
      return fm.serveResponse("404", "Filter does not exist!")
  end
end
end

--htmx
fm.setRoute({"/f", "/filters", method="PUT"}, filters_modify_handler("PUT"))
--fallback
fm.setRoute({"/f/:filter/modify", "/filters/:filter/modify", method="PUT"}, filters_modify_handler("POST"))

-- delete (DELETE)
local filters_delete_handler = function(method)
  return function(r)
    local metadata = parse_metadata_filters(r)
    local filter = r.params.filter
    local method = r.method
    if not dbm.validate_filter(filter) then
      print("Warning! Filter does not exist")
      return filters_create_handler(r)
      --return fm.serveResponse("404", "Filter does not exist!")
    elseif filter == 'all' then
      return fm.serveResponse("400", "Cannot delete filter:"..filter)
    else
      dbm.delete_filter(filter)
      if method == "GET" then
        return fm.serveRedirect("303", "/filters/all")
      elseif method == "DELETE" then
        return fm.serveRedirect("303", "/table/filters")
      end
    end
  end
end

--htmx
fm.setRoute({"/f/:filter", "/filters/:filter", method="DELETE"}, filters_delete_handler())
--fallback
fm.setRoute({"/f/:filter/delete", "/filters/:filter/delete", method="GET"}, filters_delete_handler())

--===== /tags/* =====--

local tags_handler = function(template)
    return function(r)
    local s = uti.load_settings()
    local limit = r.params.limit or s.max_pages
    local offset = r.params.offset or 0
    local filter = r.params.filter or 'all'
    assert(dbm.validate_filter(filter))
    local total_pages = dbm.count_images_by_tag(r.params.tag, filter)
    local other_filters = dbm.count_tags_by_filter(r.params.tag)
    local pages = dbm.load_images_by_tag(r.params.tag, filter, limit, offset)
    if tonumber(limit) > #pages then
      limit = #pages
    end
    return fm.serveContent(template, {tag_count = total_pages,
                                    tag = r.params.tag,
                                    other_filters = other_filters,
                                    show_meta = true,
                                    url = {tag = "filters/" .. filter .. "/tags"},
                                    limit = limit,
                                    offset = offset,
                                    filter = filter,
                                    pages = pages})

                                  end
                                end
fm.setRoute({"/f/:filter/t/:tag", "/filters/:filter/tags/:tag"}, tags_handler("tags"))
fm.setRoute({"/f/:filter/t/:tag/json", "/filters/:filter/tags/:tag/json"}, tags_handler("json"))

-- /pdfs
--

local pdf_page_handler = function(template)
  return function(r)
  local s = uti.load_settings()
  local pdf = r.params.pdf .. '.pdf'
  local fullpath = r.params.path .. '/' .. pdf
  local low = r.params.low or 1
  local high = r.params.high or s.max_pages
  local filter = r.params.filter or 'all'
  if r.params.low ~= nil or r.params.high ~= nil then
      pages = dbm.load_images_by_page_range(fullpath, low, high)
  else
      pages = dbm.load_images_by_pdf(fullpath,
                                       r.params.limit or s.max_pages)
  end
  if #pages < tonumber(high) - tonumber(low) then
    high = #pages + tonumber(low)
  end
  tags_found = dbm.get_all_tags(fullpath, low, high)

  return fm.serveContent(template, {fullpath = fullpath,
                                  tags_found = tags_found,
                                  show_meta = true,
                                  url = {pdf = "filters/" .. filter .. "/pdfs"},
                                  filter = filter,
                                  pdf = pdf,
                                  low = low,
                                  high = high,
                                  pages = pages})
  end
end


fm.setRoute("/p/*", "/f/all/p/*")
fm.setRoute({"/f/:filter/p/*path/:pdf.pdf", "/filters/:filter/pdfs/*path/:pdf.pdf"}, pdf_page_handler('pdfs'))
fm.setRoute({"/f/:filter/p/*path/:pdf/json", "/filters/:filter/pdfs/*path/:pdf/json"}, pdf_page_handler('json'))

fm.setRoute({"/p/*path/:pdf.pdf", "/pdfs/*path/:pdf.pdf"}, pdf_page_handler('pdfs'))
fm.setRoute({"/p/*path/:pdf.pdf/json", "/pdfs/*path/:pdf.pdf/json"}, pdf_page_handler('json'))

fm.setRoute({"/p/*path/:pdf.pdf/pages/(:low[%d])-(:high[%d])",
             "/pdfs/*path/:pdf.pdf/pages/(:low[%d])-(:high[%d])"}, pdf_page_handler('pdfs'))
fm.setRoute({"/p/*path/:pdf.pdf/pages/(:low[%d])-(:high[%d])/json",
             "/pdfs/*path/:pdf.pdf/pages/(:low[%d])-(:high[%d])/json"}, pdf_page_handler('json'))
-- /settings
--

fm.setRoute(fm.GET"/settings(/json)", function(r)
  return fm.serveContent("json", uti.load_settings())
end)


return fm
