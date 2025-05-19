-- DB Explorer
local fm = require "fullmoon"
local uti = require "utils" 
local dbm = require "db"

require "api"

--Config
local links = {home = "/",
               views = '/views/all',
               tags = '/tags/all',
               pdfs = '/pdfs/all',
               settings = '/settings/'}

local rolecall = {'home', 'views', 'pdfs', 'tags', 'settings'}


--Variables available to templates
fm.setTemplateVar("title", "PDF Explorer")
fm.setTemplateVar("links", links)
fm.setTemplateVar("rollcall", rolecall)
fm.setTemplateVar("lang", "en_gb")
fm.setTemplateVar("siteurl", "")
fm.setTemplateVar("header", dbm.get_metadata_keys())  -- Runs once at startup 
fm.setTemplateVar("settings", uti.load_settings())

--Functions available to templates
fm.setTemplateVar("uti", uti)  -- make utilities available to templates
fm.setTemplateVar("get_all_pdfs", dbm.get_all_pdfs)
fm.setTemplateVar("filter_pdfs", dbm.filter_pdfs)
fm.setTemplateVar("get_metadata_values", dbm.get_metadata_values)
fm.setTemplateVar("get_tag_count", dbm.get_tag_count)
fm.setTemplateVar("list_matching_pdfs", dbm.list_matching_pdfs)
fm.setTemplateVar("load_images_by_pdf", dbm.load_images_by_pdf)
fm.setTemplateVar("load_images_by_tag", dbm.load_images_by_tag)
fm.setTemplateVar("pdfs_by_tag", dbm.pdfs_by_tag)
fm.setTemplateVar("tags_by_pdf", dbm.tags_by_pdf)
fm.setTemplateVar("tags_by_pdf_and_page", dbm.tags_by_pdf_and_page)
fm.setTemplateVar("get_all_tags", dbm.get_all_tags)

fm.run()
