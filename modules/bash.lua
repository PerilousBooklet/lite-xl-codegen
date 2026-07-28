-- mod-version:3
local core = require "core"
local codegen = require 'plugins.codegen'

local shebang = [[
#!/bin/bash

]]

codegen.add_module() {
  name = "bash",
  desc = "",
  file_extensions = {},
  file_fills = {
    {
      type = "",
      content = shebang
    }
  },
  boilerplate = {},
  wrap = {},
  docs = {},
  components = {},
  properties = {}
}
