-- mod-version:3
local codegen = require 'plugins.codegen'

-- __sss__ is the tag to be replaced with the header name
local file_fill_base = [[
<!DOCTYPE html>
<html>
  
  <head>
    <title>__sss__</title>
  </head>
  
  <body>
    
    ...
    
  </body>
  
</html>
]]

codegen.add_module() {
  name = "HTML",
  desc = "",
  file_extensions = { ".html" },
  file_fills = {
    {
      type = "base",
      content = file_fill_base
    }
  },
  boilerplate = {},
  wrap = {},
  docs = {},
  components = {},
  properties = {}
}
