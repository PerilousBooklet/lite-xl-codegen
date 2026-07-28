-- mod-version:3
local core = require "core"
local codegen = require 'plugins.codegen'

-- use tag to replace component name: __COMPONENT_NAME__
-- TODO: upper-case/lower-case operations depending on where to paste the component name
local content_base_html = [[

]]

local content_base_css = [[

]]

local content_base_js = [[

]]

codegen.add_module() {
  name = "plainvanilla",
  desc = "A library of example web components from plainvanillaweb.com",
  file_extensions = {},
  file_fills = {},
  boilerplate = {},
  wrap = {},
  docs = {},
  components = {
    {
      name = "base",
      content = {
        { ["__FILENAME__.html"] = content_base_html, path = "" },
        { ["__FILENAME__.css"]  = content_base_css,  path = "" },
        { ["__FILENAME__.js"]   = content_base_js,   path = "" }
      }
    }
  },
  properties = {}
}
