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

--===== /form/filter/* =====--
local _get_form_data = function(filter)
    assert(dbm.validate_filter(filter))
    local form_data = {}
    for i, key in ipairs(dbm.get_metadata_keys()) do
      all_values = dbm.get_metadata_values(key, 'all')
      selected_values = dbm.get_metadata_values(key, filter)

      form_data[key] = {}
      for i, value in ipairs(all_values) do
        form_data[key][value] = uti.value_in_arr(value, selected_values)
      end
    end
    return form_data
end

local get_form_filter_handler = function(method, template)
  return function(r)
    filter = r.params.filter or 'all'
    return fm.serveContent(template, {method=method, filter=filter, form_data = _get_form_data(filter)})
  end
end

fm.setRoute(fm.GET"/form/filter", get_form_filter_handler('post', 'putpost-filter'))
fm.setRoute(fm.GET"/form/filter/all", get_form_filter_handler('post', 'putpost-filter'))
fm.setRoute(fm.GET"/form/filter/:filter", get_form_filter_handler('put', 'putpost-filter'))

fm.setRoute(fm.GET"/partial/form/filter", get_form_filter_handler('post', 'partial/form-filter'))
fm.setRoute(fm.GET"/partial/form/filter/all", get_form_filter_handler('post', 'partial/form-filter'))
fm.setRoute(fm.GET"/partial/form/filter/:filter", get_form_filter_handler('put', 'partial/form-filter'))

--===== /filters/:filter/view =====--
--===== /filters/* =====--
local view_filters_handler = function(template)
  return function(r)
    filter = r.params.filter
    assert(dbm.validate_filter(filter))
    return fm.serveContent(template, {filter = filter,
                                     filters = filter_table(),
                                     form_data = _get_form_data(filter),
                                     pdfs = pdf_table(filter),
                                     tags = tag_table(filter)})
  end
end

fm.setRoute("/f", fm.serveRedirect("/f/all/view"))
fm.setRoute("/filters", fm.serveRedirect("/filters/all/view"))
fm.setRoute("/f/all", fm.serveRedirect("/f/all/view"))
fm.setRoute("/filters/all", fm.serveRedirect("/filters/all/view"))

fm.setRoute({"/f/:filter/view", "/filters/:filter/view", method="GET"}, view_filters_handler("filters"))
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

--new (POST)
--modify (PUT)
--guess by hidden form attribute _method (GET)
local filters_create_handler = function(method)
  return function(r)
  local filter = r.params.filter_name
  local _method = r.params._method:lower()
  local get_method_catch = false  -- alters behaviour to no js
  if method == "get" then
    method = _method
    get_method_catch = true
  end
  r.params._method = nil
  if method == "post" then
    if dbm.validate_filter(filter) then
      return fm.serveResponse("409", "Filter already exists with name : " .. filter)
    end
  elseif method == "put" then
    if filter == "all" then
      return fm.serveResponse("400", "Invalid filter name : " .. filter)
    else
      assert(dbm.delete_filter(filter))
    end
  end
  
  local metadata = parse_metadata_filters(r)
  assert(dbm.create_new_filter(filter, metadata))
  local new_path = fm.makePath("/filters/" .. filter .. "/view")
  if get_method_catch then
    return fm.serveRedirect(200, fm.makePath("/filters/all/view"))
  end
  return fm.serveResponse(200, {["HX-Redirect"] = new_path}, "")
  end
end

fm.setRoute({"/f/new", "/filters/new", method="POST"}, filters_create_handler("post"))
fm.setRoute({"/f/:filter/modify", "/filters/:filter/modify", method="PUT"}, filters_create_handler("put"))
-- fallback
fm.setRoute({"/f/:filter/modify", "/filters/:filter/modify", method="GET"}, filters_create_handler("get"))

-- delete (DELETE)
local filters_delete_handler = function()
  return function(r)
    local metadata = parse_metadata_filters(r)
    local filter = r.params.filter
    local method = r.method
    if not dbm.validate_filter(filter) then
      print("Warning! Filter does not exist")
      return fm.serveResponse("404", "Filter does not exist!")
    elseif filter == 'all' then
      return fm.serveResponse("400", "Cannot delete filter:"..filter)
    else
      dbm.delete_filter(filter)
      if method == "GET" then
        return fm.serveRedirect("303", "/filters/all")
      elseif method == "DELETE" then

        local new_path = fm.makePath("/filters/all/view")
        return fm.serveResponse(303, {["HX-Redirect"] = new_path}, "")
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
    local limit = s.pagination
    if r.params.page ~= nil then
      offset = tonumber(r.params.page) - limit
    elseif r.params.offset ~= nil then
      offset = tonumber(r.params.offset)
    else
      offset = 0
    end
    if offset < 0 then
      offset = 0
    end
    local filter = r.params.filter or 'all'
    assert(dbm.validate_filter(filter))
    local total_pages = dbm.count_images_by_tag(r.params.tag, filter)
    assert(offset < total_pages, "exceeds limit!" .. offset .. " " .. total_pages)
    print("Getting from " .. filter .. " for tag " .. r.params.tag)
    local other_filters = dbm.count_tags_by_filter(r.params.tag)
    local pages = dbm.load_images_by_tag(r.params.tag, filter, limit, offset)
    if tonumber(limit) > #pages then
      limit = #pages
    end
    if tonumber(offset) < 0 then
      offset = 0
    end
    return fm.serveContent(template, {total_pages = total_pages,
                                    tag = r.params.tag,
                                    related = dbm.get_related(r.params.tag),
                                    aka = dbm.get_aka(r.params.tag),
                                    other_filters = other_filters,
                                    url = "/filters/" .. filter .. "/tags/" .. r.params.tag,
                                    limit = limit,
                                    offset = offset,
                                    filter = filter,
                                    pages = pages})

                                  end
                                end
fm.setRoute({"/f/:filter/t/:tag", "/filters/:filter/tags/:tag"}, tags_handler("tags"))
fm.setRoute({"/f/:filter/t/:tag/json", "/filters/:filter/tags/:tag/json"}, tags_handler("json"))
fm.setRoute({"/f/:filter/t/:tag/pages", "/filters/:filter/tags/:tag/pages"}, tags_handler("pages"))

-- /pdfs
--

local pdf_page_handler = function(template)
  return function(r)
  local s = uti.load_settings()
  local pdf = r.params.pdf .. '.pdf'
  local fullpath = r.params.path .. '/' .. pdf
  local pdfmeta = dbm.get_pdf_metadata(fullpath)
  local filter = r.params.filter or 'all'
  local limit = s.pagination
  local offset = 0
  if r.params.page ~= nil then
    offset = tonumber(r.params.page) - limit
  elseif r.params.offset ~= nil then
    offset = tonumber(r.params.offset)
  end
  if offset < 0 then
    offset = 0
  end
  local pages = dbm.load_images_by_pdf(fullpath, limit, offset)
  local tags_found = dbm.get_all_tags(fullpath, offset, offset + limit)
  return fm.serveContent(template, {fullpath = fullpath,
                                  tags_found = tags_found,
                                  url = "/pdfs/" .. fullpath,
                                  pdf_meta = pdfmeta,
                                  filter = filter,
                                  pdf = pdf,
                                  limit = limit,
                                  offset = offset,
                                  total_pages = dbm.count_pages_in_pdf(fullpath),
                                  pages = pages})
  end
end


fm.setRoute("/p/*", "/f/all/p/*")
fm.setRoute({"/f/:filter/p/*path/:pdf.pdf", "/filters/:filter/pdfs/*path/:pdf.pdf"}, pdf_page_handler('pdfs'))
fm.setRoute({"/f/:filter/p/*path/:pdf.pdf/json", "/filters/:filter/pdfs/*path/:pdf.pdf/json"}, pdf_page_handler('json'))
fm.setRoute({"/f/:filter/p/*path/:pdf.pdf/pages", "/filters/:filter/pdfs/*path/:pdf.pdf/pages"}, pdf_page_handler('pages'))

fm.setRoute({"/p/*path/:pdf.pdf", "/pdfs/*path/:pdf.pdf"}, pdf_page_handler('pdfs'))
fm.setRoute({"/p/*path/:pdf.pdf/json", "/pdfs/*path/:pdf.pdf/json"}, pdf_page_handler('json'))
fm.setRoute({"/p/*path/:pdf.pdf/pages", "/pdfs/*path/:pdf.pdf/pages"}, pdf_page_handler('pages'))

-- /settings
--

fm.setRoute(fm.GET"/settings(/json)", function(r)
  return fm.serveContent("json", uti.load_settings())
end)


return fm
