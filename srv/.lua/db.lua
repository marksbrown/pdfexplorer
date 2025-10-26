-- SQLite DB management
local fm = require "fullmoon"
local uti = require "utils"

local dbm = {}

dbm.load_db = function(name)
  -- 1. load settings
  -- 2. get name of DB
  -- 3. return
  settings = uti.load_settings()
  name = name or settings["database"]["name"]
  return assert(fm.makeStorage(name))
end

dbm.db = dbm.load_db()

dbm.get_all_groups = function()
  local cmd = [[
  select left, count(*) as count
  from tagedges
  where kind = "group"
  group by left
  order by count
  desc;
  ]]
  return dbm.db:fetchAll(cmd)
end

dbm.get_matching_left = function(tag, kind)
  local cmd = [[
  select right
  from tagedges
  where kind = (?)
  and left = (?);
  ]]
  return dbm.db:fetchAll(cmd, kind, tag)
end

dbm.get_group_children = function(tag)
  return dbm.get_matching_left(tag, 'group')
end

dbm.get_matching_right = function(tag, kind)
  local cmd = [[
  select left
  from tagedges
  where kind = (?)
  and right = (?);
  ]]
  return dbm.db:fetchAll(cmd, kind, tag)
end

dbm.get_group_parents = function(tag)
  return dbm.get_matching_right(tag, "group")
end

dbm.get_matching_both = function(tag, kind)
  local l = dbm.get_matching_left(tag, kind)
  local r = dbm.get_matching_right(tag, kind)
  local parsed = {}
  for i, v in pairs(l) do
    parsed[#parsed + 1] = v.right
  end
  for i, v in pairs(r) do
    parsed[#parsed + 1] = v.left
  end
  return parsed
end

dbm.get_related = function(tag)
  return dbm.get_matching_both(tag, "related")
end

dbm.get_aka = function(tag)
  return dbm.get_matching_both(tag, "aka")
end

-- Filters
dbm.get_all_filters = function()
  local cmd = [[
  SELECT substr(name, 9) as name
  from sqlite_schema
  where type="view"
  and name like "myviews_%";
  ]]
  return dbm.db:fetchAll(cmd)
end

dbm.validate_filter = function(filter)
  if filter == "all" then
    return true
  end
  local all_filters = dbm.get_all_filters()
  for k, v in pairs(all_filters) do 
    if v.name == filter then
      return true
    end
  end
  return false
end

dbm.delete_filter = function(filter)
  if dbm.validate_filter(filter) then
    local cmd = [[DROP view myviews_]] .. filter
    dbm.db:execute(cmd)
  else
    error(filter .. "not found")
  end
end

dbm.count_filters = function()
  local cmd = [[
  select count(*) as count
  from sqlite_schema
  where type="view"
  and name like "myviews_%";
  ]]
  return dbm.db:fetchOne(cmd).count
end

dbm.count_tag = function(tag, filter)
  local cmd = [[]]
  if filter == "all" then
    cmd = [[
    select count
    from tags
    where tag = (?);
    ]]
    return dbm.db:fetchOne(cmd, tag).count
  else
    assert(dbm.validate_filter(filter))
    local cmd = [[
    select count(tag) as count
    FROM 
    pagetags
    JOIN
    myviews_]] .. filter .. [[ as mv
    ON mv.id == pagetags.id
    WHERE tag = (?);
    ]]
  return dbm.db:fetchOne(cmd, tag).count
  end
end

dbm.count_tags = function(filter)
  local cmd = [[]]
  if filter == "all" then
    cmd = [[
    select count(*) as count
    from tags;
    ]]
    return dbm.db:fetchOne(cmd).count
  else
    print(filter)
    assert(dbm.validate_filter(filter))
    local cmd = [[
    select count(distinct tag) as count
    FROM 
    pagetags
    JOIN
    myviews_]] .. filter .. [[ as mv
    ON mv.id == pagetags.id
    ]]
  return dbm.db:fetchOne(cmd).count
  end
end

dbm.count_tags_by_filter = function(tag)
  local all_filters = dbm.get_all_filters()
  local results = {}
  for i, filter in ipairs(all_filters) do
    local c = dbm.count_images_by_tag(tag, filter.name)
    results[filter.name] = c
  end
  results['all'] = dbm.count_images_by_tag(tag, 'all')
  return results  
end

dbm.get_count_pdfs_by_filter = function(filter)
  local cmd = [[]]
  if filter == nil or filter == "all" then
    cmd = [[SELECT count(*) as count from pdfs]]
  else
    assert(dbm.validate_filter(filter))
    cmd = [[SELECT count(*) as count from myviews_]] .. filter
  end

  r = dbm.db:fetchOne(cmd)
  return r.count
end

dbm.get_pdfs_by_filter = function(filter)
  if filter == nil or filter == "all" then
    return dbm.get_all_pdfs()
  end
  local cmd = [[
  SELECT id, metadata
  FROM myviews_]] .. filter .. [[
  ORDER BY id
  DESC;]]
  local raw_data = dbm.db:fetchAll(cmd)
  local parsed = {}
  for k,v in pairs(raw_data) do
    parsed[v.id] = DecodeJson(v.metadata)
  end
  return parsed
end

dbm.get_all_pdfs = function()
  local cmd = [[
  SELECT id, metadata
  FROM pdfs
  ORDER BY id
  DESC;]]
  local raw_data = dbm.db:fetchAll(cmd)
  local parsed = {}
  for k,v in pairs(raw_data) do
    parsed[v.id] = DecodeJson(v.metadata)
  end
  return parsed
end

dbm.get_metadata_keys = function()
  local cmd = [[
    select distinct key
    from pdfs, json_tree(pdfs.metadata)
    where json_tree.type not in ('object')
    order by key ASC;
  ]]
  local d = dbm.db:fetchAll(cmd)
  local parsed = {}
  for k,v in ipairs(d) do
    parsed[#parsed + 1] = v.key
  end
  return parsed
end

-- Filter Operations
-- This is where we must ensure the following
-- 1. Stateless - we can cache results or write better SQL but it cannot preserve state
-- 2. Metadata invariant - Provided metadata can and will vary. Don't assume field names
-- 3. Secure - this is where injection attacks will arrive. So don't use string operations
-- on data insertion!

dbm.get_matching_pdfs = function(key, value)
  local in_clause = string.rep("?, ", #value):sub(1, -3) -- magic
  local cmd = [[
    select pdfs.id
    from pdfs, json_tree(pdfs.metadata)
    where key not null
    and key = (?)
    and value in (]]
    ..
    in_clause
    ..[[)
    order by pdfs.id
    DESC;
    ]]
    local raw_data = dbm.db:fetchAll(cmd, key, table.unpack(value))
    local parsed = {}
    for k, v in pairs(raw_data) do
      parsed[#parsed + 1] = v.id
    end

    return parsed
end

dbm.get_matching_metadata = function(key, value)
  -- value can be str or tbl
  -- thus need to alter cmd to fit unknown length of value
  local in_clause = string.rep("?, ", #value):sub(1, -3) -- magic
  local cmd = [[
    select pdfs.id, pdfs.metadata
    from pdfs, json_tree(pdfs.metadata)
    where key not null
    and key = (?)
    and value in (]]
    ..
    in_clause
    ..[[)
    order by pdfs.id
    DESC;
    ]]
    local raw_data = dbm.db:fetchAll(cmd, key, table.unpack(value))
    local parsed = {}
    for k,v in pairs(raw_data) do
      parsed[v.id] = DecodeJson(v.metadata)
    end
    return parsed
end


dbm.create_new_filter = function(filter, filter_by)
  local filter = "myviews_" .. filter
  local cmd = [[]]
  local parameters = {}
  local first_run = true
  valid_keys = dbm.get_metadata_keys()
  for key, values in pairs(filter_by) do
    assert(uti.value_in_arr(key, valid_keys), "Unknown key!")
    local valid_values = dbm.get_metadata_values(key)
    local tmp = [[
    select pdfs.id, pdfs.metadata
    from pdfs, json_tree(pdfs.metadata)
    where key not null
    and key = "]] .. key .. [["
    and value in (]]
    
    for i, value in ipairs(values) do
      assert(uti.value_in_arr(value, valid_values), "Unknown value!")
      tmp = tmp .. [["]] .. value .. [["]]
      if i < #values then
        tmp = tmp .. [[,]]
      else
        tmp = tmp .. [[)]]
      end
    end
    if first_run then
      cmd = tmp
      first_run = false
    else
      cmd = cmd .. " INTERSECT " .. tmp
    end
    parameters[#parameters + 1] = key
    for i, value in ipairs(values) do
      parameters[#parameters + 1] = value
    end
  end
  cmd = "create view " .. filter .."(id, metadata) as " .. cmd

  return dbm.db:execute(cmd)
end

dbm.get_matching_tags = function(pdfs)
  if #pdfs == 0 then
    print("Warning! No pdfs provided!")
    return nil
  end

  local in_clause = string.rep("?, ", #pdfs):sub(1, -3) -- magic
  local cmd = [[
  select tag, count(tag) as count
  from pagetags
  where pagetags.id in (]]
  ..
  in_clause
  ..[[)
  group by tag
  order by count desc;]]
  return dbm.db:fetchAll(cmd, table.unpack(pdfs))
end

local f = function()
  local raw_data = dbm.db:fetchAll(cmd, table.unpack(pdfs))
  local parsed = {}
  for k,v in pairs(raw_data) do
    parsed[v.tag] = {tag = v.tag, count = v.count}
  end
  return parsed
end


dbm.get_metadata_values = function(key, filter)
  local cmd = [[]]
  if filter == nil or filter == "all" then
    cmd = [[
      select distinct value
      from pdfs, json_tree(pdfs.metadata)
      where key not null
      and key = (?);
    ]]
  else
    assert(dbm.validate_filter(filter))
    cmd = [[
    select distinct value
    from myviews_]] .. filter .. [[ as mv, json_tree(mv.metadata)
    where key not null
    and key = (?);
      ]]
  end
  local d = dbm.db:fetchAll(cmd, key)
  local parsed = {}
  for i, values in ipairs(d) do
    parsed[#parsed + 1] = values.value
  end
  return parsed
end

dbm.get_metadata = function(filter)
  local keys = dbm.get_metadata_keys()
  local parsed = {}
  for i, key in ipairs(keys) do
    parsed[key] = dbm.get_metadata_values(key, filter)
  end
  return parsed
end

dbm.get_tag_count = function(tag)
  local d = dbm.db:fetchAll([[SELECT count from tags WHERE tag = (?);]], tag)
  if #d == 0 then
   return 0
  else
   return d[1].count
  end
end

dbm.list_matching_pdfs = function(pdf)
  local cmd = [[
  [[
  SELECT distinct id
  from pages
  where id
  like (?);
  ]]
return dbm.db:fetchAll(cmd, pdf)
end


dbm.load_images_by_pdf = function(pdf, max_pages)
  local cmd = [[
  select * from
  (select pages.id, page, png from pages
  where pages.id = (?) 
  order by pages.page)
  limit (?);
  ]]
return dbm.db:fetchAll(cmd, pdf, max_pages)
end

dbm.load_images_by_page_range = function(pdf, low, high)
  local cmd = [[
  select * from
  (select pages.id, page, png from pages
  where pages.id = (?)
  and pages.page >= (?)
  and pages.page <= (?)
  order by pages.page);
  ]]
  return dbm.db:fetchAll(cmd, pdf, low, high)
end

dbm.count_images_by_tag = function(tag, filter)
  local cmd = [[]]
  if filter == "all" then
  cmd = [[
  SELECT count(*) as c from (select pages.id, pages.page, png from pages
  join pagetags
  on pages.id == pagetags.id
  and pages.page == pagetags.page
  where pagetags.tag = (?));
  ]]
  else
    cmd = [[ 
  SELECT count(*) as c from (select pages.id, pages.page, png from pages
  join pagetags
  on pages.id == pagetags.id
  and pages.page == pagetags.page
  join myviews_]] .. filter .. [[ as mv
  on mv.id == pages.id
  where pagetags.tag = (?));
    ]]
  end
  return dbm.db:fetchOne(cmd, tag).c
end

dbm.load_images_by_tag = function(tag, filter, limit, offset)
  local cmd = [[]]
  if filter == "all" then
  cmd = [[
  SELECT * from (select pages.id, pages.page, png from pages
  join pagetags
  on pages.id == pagetags.id
  and pages.page == pagetags.page
  where pagetags.tag = (?)
  order by pages.id desc)
  limit (?), (?);
  ]]
  else
    cmd = [[ 
  SELECT * from (select pages.id, pages.page, png from pages
  join pagetags
  on pages.id == pagetags.id
  and pages.page == pagetags.page
  join myviews_]] .. filter .. [[ as mv
  on mv.id == pages.id
  where pagetags.tag = (?)
  order by pages.id desc)
  limit (?), (?);
    ]]
  end
  return dbm.db:fetchAll(cmd, tag, offset, limit)
end

dbm.pdfs_by_tag = function(tag)
  local cmd = [[
  SELECT id, page FROM pagetags
  WHERE
  tag = (?)
  ORDER BY
  id, page
  ASC; 
  ]]
  return dbm.db:fetchAll(cmd, tag)
end

dbm.tags_by_pdf = function(pdf)
  local cmd = [[
  SELECT distinct tag
  from pagetags
  where id = (?) 
  order by
  tag asc;
  ]]
  return dbm.db:fetchAll(cmd, pdf)
end

dbm.tags_by_pdf_and_page = function(pdf, page)
  local cmd = [[
  SELECT distinct tag
  from pagetags
  where id = (?) and page = (?) 
  order by
  tag asc;
  ]]
  return dbm.db:fetchAll(cmd, pdf, page)
end

dbm.get_tags_by_filter = function(filter, pdf)
  if filter == nil or filter == "all" then
    return dbm.get_all_tags(pdf)
  end
  if pdf ~= nil then
    local cmd = [[
  SELECT tag, COUNT(*) as count
  FROM 
  pagetags 
  JOIN
  myviews_]] .. filter .. [[ as mv
  ON mv.id == pagetags.id
  WHERE pagetags.id = (?)
  GROUP BY tag
  ORDER BY count
  DESC;]]
  return dbm.db:fetchAll(cmd, pdf)
else
  local cmd = [[
  SELECT tag, COUNT(*) as count
  FROM pagetags
  JOIN myviews_]] .. filter .. [[ as mv
  ON mv.id == pagetags.id
  GROUP BY tag
  ORDER BY count
  DESC;]]
  return dbm.db:fetchAll(cmd)
end
end

dbm.get_all_tags = function(pdf, low, high)
  if pdf ~= nil then
    if low == nil then
      local cmd = [[
      SELECT tag, COUNT(*) as count
      FROM 
      pagetags 
      where pagetags.id = (?)
      GROUP BY tag
      ORDER BY count
      DESC;]]
      return dbm.db:fetchAll(cmd, pdf)
    else
      local cmd = [[
      SELECT tag, COUNT(*) as count
      FROM 
      pagetags 
      where pagetags.id = (?)
      and pagetags.page >= (?)
      and pagetags.page <= (?)
      GROUP BY tag
      ORDER BY count
      DESC;]]
      return dbm.db:fetchAll(cmd, pdf, low, high)
    end 
  else
    local cmd = [[
    SELECT tag, COUNT(*) as count
    FROM pagetags
    GROUP BY tag
    ORDER BY count
    DESC;]]
    return dbm.db:fetchAll(cmd)
  end
  end

dbm.create_user_tables = function()
  local cmd = [[
  CREATE TABLE if not exists "filters" (
    "id"	TEXT NOT NULL UNIQUE,
    "metadata" TEXT,
    PRIMARY KEY("id")
  )

  create TABLE if not exists "collections" (
    "id" TEXT not NULL UNIQUE,
    PRIMARY KEY("id")
  );

  CREATE TABLE if not exists "pagecollections" (
    "pdfid"	TEXT,
    "page"	INTEGER,
    "collection"	TEXT,
    FOREIGN KEY("pdfid") REFERENCES "pages"("id"),
    FOREIGN KEY("page") REFERENCES "pages"("page"),
    FOREIGN KEY("collection") REFERENCES "collections"("id"),
    PRIMARY KEY("view","page","id")
  );]]
    return dbm.db:execute(cmd)
  end

return dbm
