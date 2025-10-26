-- DB Explorer
local fm = require "fullmoon"
local uti = require "utils" 
local dbm = require "db"

require "api"

--Config
local links = {home = "/",
               filters = '/filters',
               settings = '/settings'}

local rolecall = {'home', 'filters', 'settings'}


--Variables available to templates
fm.setTemplateVar("title", "PDF Explorer")
fm.setTemplateVar("links", links)
fm.setTemplateVar("rollcall", rolecall)
fm.setTemplateVar("lang", "en_gb")

local s = uti.load_settings()
fm.setTemplateVar("siteurl", s.siteurl)
fm.setTemplateVar("header", dbm.get_metadata_keys())  -- Runs once at startup 
fm.setTemplateVar("get_tags", dbm.tags_by_pdf_and_page)
fm.setTemplateVar("get_group_children", dbm.get_group_children)
fm.setTemplateVar("count_tag", dbm.count_tag)
fm.setTemplateVar("settings", s)


fm.run()
