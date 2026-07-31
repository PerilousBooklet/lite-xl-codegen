-- mod-version:3
local codegen = require 'plugins.codegen'

-- WIP: FILE FILL
local file_fill_package_path = [[
package main;

public class Main {

  // ...

}
]]

-- BOILERPLATE
-- __THIS__ is a list of items to be constructed in the plugin's logic
-- __REFERENCE_ATTR_IN_METHOD__ is the name adjusted as per camelCase convention
-- __REFERENCE_ATTR__ is the original attribute name
local boilerplate_constructor = [[
public __REFERENCE_ATTR__ {
  __THIS__
}
]]
local boilerplate_getter = [[
public String get__REFERENCE_ATTR_IN_METHOD__() {
  return __REFERENCE_ATTR__;
}
]]
local boilerplate_setter = [[
public void set__REFERENCE_ATTR_IN_METHOD__(String __REFERENCE_ATTR__) {
    this.__REFERENCE_ATTR__ = __REFERENCE_ATTR__;
  }
]]

-- WRAP
-- __CODE__ is the selected code to be wrapped
local wrap_try = [[
try () {
  __CODE__
}
]]
local wrap_try_catch = [[
try () {
  __CODE__
} catch () {
  
}
]]
local wrap_try_catch_finally = [[
try () {
  __CODE__
} catch () {
  
} finally {
  
}
]]

-- DOCS
-- Placeholder convention (see init.lua's expand_doc_template):
--   __NAME__          -> substituted inline with the symbol's name
--   __PARAMS_BLOCK__  -> alone on its own line; expands to one
--                        "* @param x" line per method parameter, or is
--                        removed entirely (methods only, and only when
--                        there are parameters)
--   __RETURN_BLOCK__  -> alone on its own line; expands to a single
--                        "* @return <type>" line for non-void methods,
--                        removed otherwise
local docs_package = [[
/**
 * __NAME__ package.
 */
]]
local docs_class = [[
/**
 * __NAME__ class.
 */
]]
local docs_interface = [[
/**
 * __NAME__ interface.
 */
]]
local docs_enum = [[
/**
 * __NAME__ enum.
 */
]]
local docs_attribute = [[
/**
 * __NAME__.
 */
]]
local docs_method = [[
/**
 * __NAME__.
 *
 * __PARAMS_BLOCK__
 * __RETURN_BLOCK__
 */
]]

-- TODO: COMPONENTS
-- Init
codegen.add_module() {
  name = "java",
  desc = "",
  file_extensions = { ".java" },
  file_fills = {
    {
      type = "package_path",
      content = file_fill_package_path
    }
  },
  boilerplate = {
    {
      type = "constructor",
      -- '{' is the anchor match, 1 is the number of lines to jump above the anchor before it starts pasting code
      anchor = { "{", 1 },
      content = boilerplate_constructor
    },
    {
      type = "getter",
      is_oneliner = true,
      anchor = { "}", 2 },
      content = boilerplate_getter
    },
    {
      type = "setter",
      is_oneliner = false,
      anchor = { "}", 2 },
      content = boilerplate_setter
    }
  },
  wrap = {
    {
      name = "try",
      content = wrap_try
    },
    {
      name = "try_catch",
      content = wrap_try_catch
    },
    {
      name = "try_catch_finally",
      content = wrap_try_catch_finally
    },
  },
  docs = {
    {
      type = "package",
      content = docs_package
    },
    {
      type = "class",
      content = docs_class
    },
    {
      type = "interface",
      content = docs_interface
    },
    {
      type = "enum",
      content = docs_enum
    },
    {
      type = "attribute",
      content = docs_attribute
    },
    {
      type = "method",
      content = docs_method
    },
  },
  components = {
    -- ?: Entity + EntityDAO + EntityService + EntityController
    -- ?: Entity + EntityDTO + EntityJpaRepository + EntityService + EntityController
  },
  properties = {
    ["root_package_path"] = {
      "src/main/java/"
    }
  }
}
