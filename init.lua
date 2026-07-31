-- mod-version:3
local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local TreeView = require "plugins.treeview"
local DocView = require "core.docview"

local fsutils = require "plugins.codegen.fsutils"

-- FIX: file-fill only appears when I press the file item in the treeview
-- FIX: boilerplate should be wrapped in one-line thick lines of space
-- FIX: remove empty line underneath doc comment
-- FIX: file_fill

-- REVIEW: remove unnecessary comments
-- REVIEW: full code review

-- TODO: auto-determine the proper package path (es. for java) based on ?

-- TODO: allows updating boilerplate code
--       (run command -> check if boilerplate already exists -> update it)
--       (or also remove boilerplate containing unknown names)

-- TODO: component generation
--       (es. java: entity class, bastano il nome della class, che contiene il percorso relativo)
--       (e i nomi degli attributi/campi)
--       (usa comando e context menu)

-- TODO: add cli code doc generators (es. jautodoc for Java, ...) integration
--       (es. generate documentation comments for all elements of a source file)

-------
-- ? --
-------

local codegen = {}
local modules = {}

---------------------------
-- Configuration Options --
---------------------------

config.plugins.codegen = common.merge({
  -- ?
}, config.plugins.codegen)

-----------------------
-- Utility functions --
-----------------------

local function get_active_docview()
  local av = core.active_view
  if getmetatable(av) == DocView and av.doc and av.doc.filename then
    return av
  end
  return nil
end

------------------
-- Data Storage --
------------------

function codegen.add_module()
	return function (t)
    table.insert(modules, t)
  end
end

local function parse_list()
	local list = system.list_dir(USERDIR .. "/plugins/codegen/modules")
  local list_matched = {}
  local temp_string = ""
  for k, v in pairs(list) do
    temp_string = string.gsub(list[k], ".lua", "")
    table.insert(list_matched, temp_string)
  end
  return list_matched
end

function codegen.load()
  local modules_list = parse_list()
  for _, v in ipairs(modules_list) do
    require("plugins.codegen.modules." .. v)
    core.log("Loaded codegen module: " .. v)
  end
end

--------------------------
-- Generation Functions --
--------------------------

local function test()
  core.log(common.serialize(TreeView.hovered_item))
  core.log(common.serialize(TreeView.hovered_item.abs_filename))
end

local function test_in_doc()
  local current_docview = get_active_docview()
  -- ?
end

local function test_global()
  core.log("TEST GLOBAL")
end

local function test_global_folder()
  core.log("TEST FOLDER")
end

local function test_global_file()
  core.log("TEST FILE")
end

-- NOTE: returns the actual module table on first match
-- (previously returned common.serialize(module), a string dump of the
-- table rather than the table itself -- that's why callers indexing
-- fields like .file_fills or .boilerplate were silently broken)
local function select_module(file_extension)
  for _, module in ipairs(modules) do
  	for _, extension in ipairs(module.file_extensions) do
  	  if extension == file_extension then
  	    return module
  	  end
  	end
  end
  return nil
end

-- Automatic FILE FILL of New Named Doc
local old_open_doc = core.open_doc -- Get old function content
-- Extend old function
function core.open_doc(filename, ...)
  -- Inherit old function content
  local doc = old_open_doc(filename, ...)
  -- New logic
  -- TODO: draw commandview to select file fill type
  local file_extension = string.match(filename, "%.%a+$")
  local selected_module = select_module(file_extension)
  -- WIP: get package path for new Java file, set it and write it (get the pkg path root from the properties table)
  --
  -- BUG FOUND: this used to gate on `system.get_file_info(filename) == nil`
  -- ("the file doesn't exist on disk yet"), checked *before* calling
  -- old_open_doc. That's backwards for the actual "New File" flow: the
  -- tree view's New File command creates an empty file on disk first
  -- (io.open(path, "w"):close()) and only *then* calls core.open_doc on
  -- it. By the time this function ran, the file already existed --
  -- file_exists was always true for exactly the brand-new files this was
  -- supposed to fire on, so `not file_exists` was always false and the
  -- fill never ran. It would only have worked for a filename that truly
  -- had no file behind it anywhere, which doesn't happen in the normal
  -- "create a new named file" workflow.
  --
  -- Checking whether the doc's *content* is empty instead works
  -- regardless of when or whether something pre-created the file on disk,
  -- and still avoids re-filling a file you've already filled and saved
  -- (its content is no longer empty at that point).
  local is_empty_doc = #doc.lines <= 1 and (doc.lines[1] or ""):match("^%s*$") ~= nil
  if doc.filename == filename and is_empty_doc and selected_module
     and selected_module.file_fills and #selected_module.file_fills > 0 then
    -- file_fills entries are tables ({ type = ..., content = ... }), and each
    -- must be inserted in order -- inserting every entry at the fixed
    -- position (1,1) in a loop would reverse their order, so build the
    -- whole block first and insert it once.
    local fill_lines = {}
    for _, file_fill in ipairs(selected_module.file_fills) do
      table.insert(fill_lines, file_fill.content or "")
    end
    doc:insert(1, 1, table.concat(fill_lines, "\n"))
  end
  -- Return expected output (See old function)
  return doc
end

-- TODO: add file_fill func. to New File from treeview context menu

-- NOTE: requires interaction with `lsp` to get the symbols data
-- Writes text into existing file starting from given position in the doc (specified in module)
-- (anchor: es. Java: line containing '}' + 1 line above, add one empty line above generated text)
-- (code: es. Java: getter/setter boilerplate code)
local function write_text_into_doc(anchor, text)
  -- TODO: write starting from given anchor: (line,col)
  -- EXAMPLE: selected symbol line (es. javadoc comment for Java class/method/attribute)
  -- EXAMPLE: contructors/getters/setters/... starting from one empty line above last line of current doc (1 indentation inside class)
  -- TODO: get selection and replace with wrapped selection
  -- EXAMPLE: wrap selected block of code with try-catch
end

-- maybe write_text_into_doc() is enough ?
local function wrap_text(anchor, text, wrap_line_top, wrap_line_bottom)
	-- ?
end

local SEP = PATHSEP or "/"

-- Creates folder_path/folder_name if it doesn't already exist and returns
-- the resulting full path (or the existing path, if it was already there).
-- Returns nil (and logs an error) on failure.
local function create_folder(folder_path, folder_name)
  local full_path = folder_path
  if folder_name and folder_name ~= "" then
    full_path = folder_path .. SEP .. folder_name
  end
  if fsutils.is_object_exist(full_path) then
    if fsutils.is_dir(full_path) then
      return full_path
    end
    core.error("[codegen] \"%s\" already exists and is not a folder", full_path)
    return nil
  end
  local ok, err = system.mkdir(full_path)
  if not ok then
    core.error("[codegen] Could not create folder \"%s\": %s", full_path, err or "unknown error")
    return nil
  end
  return full_path
end

-- Creates file_path/file_name with file_content and returns the full path,
-- or nil (and logs an error) if the file already exists or can't be
-- written. Deliberately refuses to overwrite an existing file -- codegen
-- should never silently clobber something you already wrote by hand.
local function create_and_fill_file(file_path, file_name, file_content)
  local full_path = file_path .. SEP .. file_name
  if fsutils.is_object_exist(full_path) then
    core.error("[codegen] File already exists, skipping: %s", full_path)
    return nil
  end
  local file, err = io.open(full_path, "wb")
  if not file then
    core.error("[codegen] Could not create file \"%s\": %s", full_path, err or "unknown error")
    return nil
  end
  file:write(file_content or "")
  file:close()
  return full_path
end

-- Creates every folder along relative_path (which may contain several
-- "/"-separated segments) under base_dir, and returns the deepest folder's
-- full path. Returns base_dir unchanged if relative_path is empty.
local function ensure_dir_path(base_dir, relative_path)
  local dir = base_dir
  if not relative_path or relative_path == "" then
    return dir
  end
  for segment in relative_path:gmatch("[^/\\]+") do
    dir = create_folder(dir, segment)
    if not dir then
      return nil
    end
  end
  return dir
end

-----------------------------
-- Boilerplate: Helpers    --
-----------------------------

-- Splits a comma-separated string into a trimmed list, e.g.
-- "name, age" -> { "name", "age" }
local function split_csv(text)
  local out = {}
  for piece in (text or ""):gmatch("[^,]+") do
    local trimmed = piece:match("^%s*(.-)%s*$")
    if trimmed ~= "" then
      table.insert(out, trimmed)
    end
  end
  return out
end

-- "name" -> "Name" (used to build getName/setName from a field called name)
local function capitalize(word)
  return word:sub(1, 1):upper() .. word:sub(2)
end

local function get_indent_unit()
  if config.tab_type == "hard" then
    return "\t"
  end
  return string.rep(" ", config.indent_size or 2)
end

local function get_line_indent(line)
  return line:match("^[ \t]*") or ""
end

-- Finds the line number of the first (search_from_start = true) or last
-- (search_from_start = false) line containing anchor_char as a plain
-- substring. Returns nil if not found.
local function find_anchor_line(doc, anchor_char, search_from_start)
  if search_from_start then
    for i = 1, #doc.lines do
      if doc.lines[i]:find(anchor_char, 1, true) then
        return i
      end
    end
  else
    for i = #doc.lines, 1, -1 do
      if doc.lines[i]:find(anchor_char, 1, true) then
        return i
      end
    end
  end
  return nil
end

-- Best-effort detection of the enclosing class name, used to build
-- constructor signatures automatically (es. "public ClassName(...) {").
-- Falls back to "ClassName" if nothing is found.
local function detect_class_name(doc)
  for i = 1, #doc.lines do
    local name = doc.lines[i]:match("class%s+([%w_]+)")
    if name then
      return name
    end
  end
  return "ClassName"
end

-- Fills a boilerplate item's content template for one or more attributes
-- and returns the finished block of text (not yet indented/inserted).
--
-- NOTE on placeholder semantics, inferred from modules/java.lua:
--   __REFERENCE_ATTR__            -> for constructor: full signature
--                                     ("ClassName(String a, String b)")
--                                     for getter/setter: the raw field name
--   __REFERENCE_ATTR_IN_METHOD__  -> capitalized field name, for method
--                                     names like getName/setName
--   __THIS__                      -> constructor-only: "this.x = x;" lines
--
-- NOTE on attribute types: this assumes String fields (matching the
-- example templates in modules/java.lua, which are all typed String).
-- If you want per-attribute types, extend the attribute prompt to accept
-- "type name" pairs instead of bare names.
local function fill_boilerplate(item, attrs, base_indent)
  local body_indent = base_indent .. get_indent_unit()

  if item.type == "constructor" then
    -- doc isn't available here, so class name detection happens in the
    -- caller and is passed through via attrs[1] special-cased below --
    -- kept simple: caller passes class_name as attrs.class_name
    local class_name = attrs.class_name or "ClassName"
    local params, assigns = {}, {}
    for _, attr in ipairs(attrs) do
      table.insert(params, "String " .. attr)
      table.insert(assigns, body_indent .. "this." .. attr .. " = " .. attr .. ";")
    end
    local signature = class_name .. "(" .. table.concat(params, ", ") .. ")"
    local filled = item.content:gsub("__REFERENCE_ATTR__", signature)
    filled = filled:gsub("__THIS__", table.concat(assigns, "\n"))
    return filled
  end

  -- getter / setter / any other single-attribute boilerplate type:
  -- generate one block per attribute and join them.
  local blocks = {}
  for _, attr in ipairs(attrs) do
    local method_name = capitalize(attr)
    local filled = item.content:gsub("__REFERENCE_ATTR_IN_METHOD__", method_name)
    filled = filled:gsub("__REFERENCE_ATTR__", attr)
    if item.is_oneliner then
      -- Collapse the (multi-line) template into a single line, e.g.
      -- "public String getName() { return name; }"
      filled = filled:gsub("[\r\n]+", " "):gsub("%s%s+", " ")
      filled = filled:match("^%s*(.-)%s*$")
    end
    table.insert(blocks, filled)
  end
  return table.concat(blocks, "\n")
end

-----------
-- Logic --
-----------

-- TODO: add context menu items for each action
--       (look at the treeview-extender plugin; add Generate->Constructor,Getter,Setter,Component,... and Refactor, works for a folder or a file)
-- TODO: es. Java: use last } as anchor and paste new content 2 lines above it (check that above paste position there are 2 empty lines)
-- TODO: check current file extension (commands must have context: current doc) and show options (defined in module) with commandview
--       (es. getters, setters, getters and setters, toString, ...)
--       1. override command: New Named Doc -> add file extension check -> show file-type commandview

-- Applies one boilerplate item (constructor/getter/setter/...) to the doc,
-- for the given comma-separated attribute names.
--
-- Anchor semantics (item.anchor = { anchor_char, jump }), inferred from the
-- module definitions and the note at the top of this file
-- ("line containing '}' + 1 line above"):
--   anchor_char == "{" -> anchor on the FIRST "{" in the file (typically the
--                         class declaration brace) and paste `jump` lines
--                         BELOW it (i.e. just inside the class body).
--   anchor_char == "}" -> anchor on the LAST "}" in the file (typically the
--                         class closing brace) and paste `jump` lines ABOVE
--                         it (i.e. just before the class ends).
-- This is an assumption based on the only two anchors currently defined in
-- modules/java.lua; if you add anchors on other characters you'll want to
-- make the direction explicit in the module instead of inferring it here.
local function generate_boilerplate_apply(doc, item, attr_text)
  local attrs = split_csv(attr_text)
  if #attrs == 0 then
    core.error("[codegen] No attribute name provided")
    return
  end
  attrs.class_name = detect_class_name(doc)

  local anchor_char, jump = item.anchor[1], item.anchor[2]
  local search_from_start = (anchor_char == "{")
  local anchor_line = find_anchor_line(doc, anchor_char, search_from_start)
  if not anchor_line then
    core.error("[codegen] Could not find anchor '%s' in document", anchor_char)
    return
  end

  local paste_line
  if anchor_char == "{" then
    paste_line = anchor_line + jump
  else
    paste_line = math.max(1, anchor_line - jump)
  end

  local base_indent = get_line_indent(doc.lines[anchor_line])
  local body_indent = base_indent .. get_indent_unit()

  local filled = fill_boilerplate(item, attrs, base_indent)

  -- Re-indent every non-empty generated line to body_indent, and pad the
  -- inserted block with a blank line above/below so it doesn't collide
  -- with existing code at the paste line.
  local final_lines = {}
  for line in (filled .. "\n"):gmatch("(.-)\n") do
    if line:match("%S") then
      table.insert(final_lines, body_indent .. (line:match("^%s*(.-)%s*$")))
    else
      table.insert(final_lines, "")
    end
  end

  local insert_text = table.concat(final_lines, "\n") .. "\n\n"
  doc:insert(paste_line, 1, insert_text)
  core.log("[codegen] Inserted %s boilerplate for: %s", item.type, table.concat(attrs, ", "))
end

-- Entry point: figures out which module applies to the current doc, lets
-- the user pick a boilerplate type via the command view, then asks for the
-- attribute name(s) to fill it in with.
local function generate_boilerplate()
  local current_docview = get_active_docview()
  if not current_docview then
    core.error("[codegen] No active document")
    return
  end
  local doc = current_docview.doc
  local file_extension = string.match(doc.filename or "", "%.%a+$")
  local selected_module = select_module(file_extension)
  if not selected_module or not selected_module.boilerplate or #selected_module.boilerplate == 0 then
    core.error("[codegen] No boilerplate definitions for this file type")
    return
  end

  local type_names = {}
  for _, item in ipairs(selected_module.boilerplate) do
    table.insert(type_names, item.type)
  end

  core.command_view:enter("Boilerplate type (" .. table.concat(type_names, ", ") .. ")", {
    submit = function(text)
      local chosen
      for _, item in ipairs(selected_module.boilerplate) do
        if item.type == text then
          chosen = item
          break
        end
      end
      if not chosen then
        core.error("[codegen] Unknown boilerplate type: %s", text)
        return
      end
      core.command_view:enter("Attribute name(s), comma-separated", {
        submit = function(attr_text)
          generate_boilerplate_apply(doc, chosen, attr_text)
        end
      })
    end,
    suggest = function(text)
      local res = {}
      for _, name in ipairs(type_names) do
        if name:find(text, 1, true) then
          table.insert(res, { text = name })
        end
      end
      return res
    end
  })
end

-----------------------------
-- Wrap Selection: Helpers --
-----------------------------

-- Adds one extra indent level to every non-blank line of `text`, leaving
-- existing (absolute) indentation on each line untouched -- per note #9 at
-- the top of this file: "for wrapping code blocks, add one more level of
-- indentation to all lines". Returns a list of lines, not a joined string,
-- since the caller needs to interleave them with the wrap template's own
-- structural lines.
--
-- ASSUMPTION: this expects the selection to cover whole lines (col1 at or
-- near the start of line1, col2 at or near the end of line2), the same way
-- you'd select a statement or block to wrap it. If the selection starts or
-- ends mid-line, the partial first/last line won't carry its original
-- leading indentation (get_text() only returns what's inside the
-- selection), so it'll look one level short. Select full lines to avoid
-- this.
local function indent_block_one_level(text)
  local unit = get_indent_unit()
  local out = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do
    if line:match("%S") then
      table.insert(out, unit .. line)
    else
      table.insert(out, "")
    end
  end
  return out
end

-- Fills a wrap template's __CODE__ placeholder with the (already
-- one-level-indented) selected code, and prefixes every other non-blank
-- template line with base_indent so the wrapper itself (e.g. "try () {")
-- lines up with the code around the original selection.
local function fill_wrap_template(template, code_lines, base_indent)
  local out = {}
  for line in (template .. "\n"):gmatch("(.-)\n") do
    local stripped = line:match("^%s*(.-)%s*$")
    if stripped == "__CODE__" then
      for _, code_line in ipairs(code_lines) do
        table.insert(out, code_line)
      end
    elseif stripped == "" then
      table.insert(out, "")
    else
      table.insert(out, base_indent .. stripped)
    end
  end
  return table.concat(out, "\n")
end

local function wrap_code_selection_apply(doc, item, line1, col1, line2, col2, selected_text)
  local code_lines = indent_block_one_level(selected_text)
  local base_indent = get_line_indent(doc.lines[line1])
  local wrapped_text = fill_wrap_template(item.content, code_lines, base_indent)

  doc:remove(line1, col1, line2, col2)
  doc:insert(line1, col1, wrapped_text)
  core.log("[codegen] Wrapped selection with \"%s\"", item.name)
end

-- TODO: Wrap code selection (context: current doc, command),
--       wrap selected code (es. try-catch-finally, ...),
--       add items to Doc context menu
--       1. get selection
--       2. add lines, add one indent to selected code
--       3. replace selection
--
-- NOTE: only handles a single selection. Multi-cursor wrapping (see note #6
-- at the top of this file) would need collecting every selection's range
-- and text up front, then applying removals/insertions in reverse, the
-- same way generate_doc_comments() processes multiple symbols -- left for
-- later since it's a bigger UX question (one command-view prompt per
-- selection, or one wrap type applied to all of them at once?).
local function wrap_code_selection()
  local current_docview = get_active_docview()
  if not current_docview then
    core.error("[codegen] No active document")
    return
  end
  local doc = current_docview.doc
  local line1, col1, line2, col2 = doc:get_selection()
  if line1 == line2 and col1 == col2 then
    core.error("[codegen] Select some code to wrap first")
    return
  end

  local file_extension = string.match(doc.filename or "", "%.%a+$")
  local selected_module = select_module(file_extension)
  local wrap_list = selected_module and selected_module.wrap
  if not wrap_list or #wrap_list == 0 then
    core.error("[codegen] No wrap definitions for this file type")
    return
  end

  local names = {}
  for _, item in ipairs(wrap_list) do
    table.insert(names, item.name)
  end

  -- Snapshot the selection now: by the time the command view's submit
  -- callback runs, the doc itself hasn't changed (focus moved to the
  -- command view, not the doc), but grabbing the text here keeps the
  -- capture and the prompt visibly tied together.
  local selected_text = doc:get_text(line1, col1, line2, col2)

  core.command_view:enter("Wrap with (" .. table.concat(names, ", ") .. ")", {
    submit = function(text)
      local chosen
      for _, item in ipairs(wrap_list) do
        if item.name == text then
          chosen = item
          break
        end
      end
      if not chosen then
        core.error("[codegen] Unknown wrap type: %s", text)
        return
      end
      wrap_code_selection_apply(doc, chosen, line1, col1, line2, col2, selected_text)
    end,
    suggest = function(text)
      local res = {}
      for _, name in ipairs(names) do
        if name:find(text, 1, true) then
          table.insert(res, { text = name })
        end
      end
      return res
    end
  })
end

-----------------------------
-- Doc Comments: Helpers   --
-----------------------------

-- Deliberately NOT calling into the `lsp` plugin here: this project
-- doesn't vendor its source, so there's no reliable contract for its
-- symbol-query API to build against without guessing at function names
-- that might not exist. Instead, this does lightweight pattern matching
-- directly on the buffer text. It's Java-shaped (matching the only module
-- that currently defines `docs` entries) and has known gaps -- it won't
-- follow multi-line signatures, annotations on their own line, generics
-- with commas in parameter types, or lambdas. If you wire in real LSP
-- symbol data later, the seam to replace is `detect_symbol_at_line` below:
-- keep its return shape ({ type, name, params, return_type }) and
-- everything downstream (template lookup, placeholder filling, insertion)
-- keeps working unchanged.

local MODIFIER_KEYWORDS = {
  "public", "private", "protected", "static", "final",
  "abstract", "synchronized", "native", "default", "strictfp"
}

local CONTROL_KEYWORDS = {
  ["if"] = true, ["for"] = true, ["while"] = true, ["switch"] = true,
  ["catch"] = true, ["return"] = true, ["new"] = true, ["throw"] = true,
  ["else"] = true, ["do"] = true, ["try"] = true, ["finally"] = true
}

local function strip_modifiers(text)
  local changed = true
  while changed do
    changed = false
    for _, kw in ipairs(MODIFIER_KEYWORDS) do
      local new_text, n = text:gsub("^%s*" .. kw .. "%s+", "")
      if n > 0 then
        text = new_text
        changed = true
      end
    end
  end
  return text
end

-- Splits a Java parameter list on top-level commas and returns just the
-- parameter names (drops the types). Doesn't handle generic types that
-- themselves contain commas (e.g. Map<String, Integer> m) -- a known
-- limitation of doing this with patterns instead of a real parser.
local function split_params(params_str)
  local params = {}
  for piece in (params_str or ""):gmatch("[^,]+") do
    local name = piece:match("([%w_]+)%s*$")
    if name then
      table.insert(params, name)
    end
  end
  return params
end

-- Attempts to recognize a Java declaration on a single line and returns
-- { type, name, params, return_type } or nil if the line doesn't look like
-- one of package/class/interface/enum/method/attribute.
local function detect_symbol_at_line(line)
  local pkg_name = line:match("^%s*package%s+([%w%.]+)%s*;")
  if pkg_name then
    return { type = "package", name = pkg_name }
  end

  for _, kw in ipairs({ "class", "interface", "enum" }) do
    local name = line:match("%f[%a]" .. kw .. "%f[%A]%s+([%w_]+)")
    if name then
      return { type = kw, name = name }
    end
  end

  local stripped = strip_modifiers(line:match("^%s*(.-)%s*$") or "")

  -- Method: TYPE NAME(PARAMS), optionally followed by "{" or ";"
  local return_type, name, params_str = stripped:match(
    "^([%w_][%w_<>%[%]%.,%s]-)%s+([%w_]+)%s*%(([^%)]*)%)%s*[{;]?%s*$"
  )
  if name and not CONTROL_KEYWORDS[name] then
    return {
      type = "method",
      name = name,
      return_type = return_type,
      params = split_params(params_str)
    }
  end

  -- Attribute/field: TYPE NAME [= ...];  (no parentheses anywhere on the line)
  if not stripped:find("(", 1, true) then
    local field_name = stripped:match("^[%w_][%w_<>%[%]%.,%s]-%s+([%w_]+)%s*[=;]")
    if field_name and not CONTROL_KEYWORDS[field_name] then
      return { type = "attribute", name = field_name }
    end
  end

  return nil
end

-- Per the original TODO: "check that symbol doesn't already have doc
-- comments above". Walks upward past any blank lines and checks whether
-- the next non-blank line looks like the end (or the whole) of a block
-- comment.
local function has_doc_comment_above(doc, line_num)
  local i = line_num - 1
  while i >= 1 and doc.lines[i]:match("^%s*$") do
    i = i - 1
  end
  if i < 1 then
    return false
  end
  local above = doc.lines[i]
  return above:find("%*/%s*$") ~= nil
end

local function get_docs_item(selected_module, symbol_type)
  if not selected_module or not selected_module.docs then
    return nil
  end
  for _, item in ipairs(selected_module.docs) do
    if item.type == symbol_type then
      return item
    end
  end
  return nil
end

-- Fills a docs_* template with the detected symbol's details.
--
-- Placeholder convention (this plugin's own -- the module's docs_* fields
-- are currently empty, so this is the contract for whoever fills them in):
--   __NAME__          -> substituted inline, anywhere in a line, with the
--                         symbol's name (class name, method name, field
--                         name, or package path).
--   __PARAMS_BLOCK__   -> must be the only thing on its line (aside from a
--                         leading "* "). Expands to one "* @param x" line
--                         per method parameter, or is removed entirely if
--                         the method takes none (or the symbol isn't a
--                         method).
--   __RETURN_BLOCK__   -> same rule as __PARAMS_BLOCK__. Expands to a
--                         single "* @return ..." line for non-void
--                         methods, or is removed for void methods/other
--                         symbol types.
-- Example modules/java.lua template using this convention:
--   local docs_method = [[
--   /**
--    * __NAME__
--    *
--    * __PARAMS_BLOCK__
--    * __RETURN_BLOCK__
--    */
--   ]]
local function expand_doc_template(template, name, params, return_type)
  local param_lines = {}
  for _, p in ipairs(params or {}) do
    table.insert(param_lines, "* @param " .. p)
  end
  local return_line = nil
  if return_type and return_type ~= "void" then
    return_line = "* @return " .. return_type
  end

  local out = {}
  for line in (template .. "\n"):gmatch("(.-)\n") do
    local stripped = line:gsub("^%s*", "")
    if stripped == "__PARAMS_BLOCK__" or stripped == "* __PARAMS_BLOCK__" then
      for _, pl in ipairs(param_lines) do
        table.insert(out, pl)
      end
    elseif stripped == "__RETURN_BLOCK__" or stripped == "* __RETURN_BLOCK__" then
      if return_line then
        table.insert(out, return_line)
      end
    else
      table.insert(out, (line:gsub("__NAME__", name or "")))
    end
  end
  return table.concat(out, "\n")
end

-- Generates (and inserts) a doc comment for the symbol on doc.lines[line_num].
-- Returns true if something was inserted, false if it was skipped (no
-- recognizable symbol, already documented, or no usable template) -- the
-- false case is expected/normal, not a hard failure.
local function generate_doc_comment_at(doc, line_num)
  if has_doc_comment_above(doc, line_num) then
    core.log("[codegen] Line %d already has a doc comment above it, skipping", line_num)
    return false
  end

  local symbol = detect_symbol_at_line(doc.lines[line_num])
  if not symbol then
    core.error("[codegen] No recognizable declaration on line %d", line_num)
    return false
  end

  local file_extension = string.match(doc.filename or "", "%.%a+$")
  local selected_module = select_module(file_extension)
  local docs_item = get_docs_item(selected_module, symbol.type)
  if not docs_item then
    core.error("[codegen] No doc template for symbol type \"%s\" in this file's module", symbol.type)
    return false
  end
  if docs_item.content:match("^%s*$") then
    core.error(
      "[codegen] Doc template for \"%s\" is empty -- fill in docs_%s in your module before using this",
      symbol.type, symbol.type
    )
    return false
  end

  local filled = expand_doc_template(docs_item.content, symbol.name, symbol.params, symbol.return_type)

  -- Doc comments sit at the same indentation as the symbol they describe
  -- (not one level deeper, unlike boilerplate bodies).
  local base_indent = get_line_indent(doc.lines[line_num])
  local final_lines = {}
  for line in (filled .. "\n"):gmatch("(.-)\n") do
    if line:match("%S") then
      table.insert(final_lines, base_indent .. line:match("^%s*(.-)%s*$"))
    else
      table.insert(final_lines, "")
    end
  end

  doc:insert(line_num, 1, table.concat(final_lines, "\n") .. "\n")
  core.log("[codegen] Inserted %s doc comment for \"%s\"", symbol.type, symbol.name)
  return true
end

-- TODO: command to auto-generate doc comments for all project file (es.
--       all .java files in project folder) (?) -- this would mean
--       operating on files that aren't necessarily open in a docview, so
--       it needs its own read/write path rather than reusing doc:insert;
--       left for later.
local function generate_doc_comment()
  local current_docview = get_active_docview()
  if not current_docview then
    core.error("[codegen] No active document")
    return
  end
  local doc = current_docview.doc
  local line1 = doc:get_selection()
  generate_doc_comment_at(doc, line1)
end

local function generate_doc_comments()
  local current_docview = get_active_docview()
  if not current_docview then
    core.error("[codegen] No active document")
    return
  end
  local doc = current_docview.doc

  -- Collect every recognizable symbol line first, in one pass over the
  -- untouched doc, then apply insertions bottom-to-top. Inserting a
  -- comment above one symbol shifts every line below it down -- see note
  -- #6 at the top of this file -- so processing in reverse means each
  -- insertion only affects line numbers we've already handled.
  local target_lines = {}
  for i = 1, #doc.lines do
    if detect_symbol_at_line(doc.lines[i]) then
      table.insert(target_lines, i)
    end
  end

  local inserted, skipped = 0, 0
  for i = #target_lines, 1, -1 do
    if generate_doc_comment_at(doc, target_lines[i]) then
      inserted = inserted + 1
    else
      skipped = skipped + 1
    end
  end
  core.log("[codegen] Doc comments: %d inserted, %d skipped", inserted, skipped)
end

-- Writes out one component's files under target_dir, inside a new folder
-- named name_text so the whole component is isolated together (e.g.
-- target_dir/login/login.html, target_dir/login/login.css, ...).
--
-- component.content is a list of file definitions, each shaped like:
--   { ["__FILENAME__.html"] = content_template, path = "" }
-- i.e. exactly one non-"path" key, whose key is the filename template and
-- whose value is the file's content template. "path" is a (possibly
-- empty, possibly nested "a/b") subfolder *inside the new component
-- folder* to write that particular file into.
--
-- Placeholders, per the comment in modules/plainvanilla.lua:
--   __FILENAME__        -> substituted in the filename
--   __COMPONENT_NAME__  -> substituted in the file content
-- Both are replaced with name_text as-is. The module's own TODO about
-- upper/lower-casing depending on where the name lands (e.g. PascalCase
-- for a class vs kebab-case for a custom element tag) isn't handled here --
-- if you need that, generate case variants of name_text and substitute a
-- distinct placeholder for each variant.
local function generate_component_apply(target_dir, component, name_text)
  if not name_text or name_text:match("^%s*$") then
    core.error("[codegen] No component name provided")
    return
  end

  local component_root = create_folder(target_dir, name_text)
  if not component_root then
    return
  end

  local created = {}
  for _, file_def in ipairs(component.content) do
    local filename_template, content_template
    for key, value in pairs(file_def) do
      if key ~= "path" then
        filename_template, content_template = key, value
      end
    end

    if filename_template then
      local dest_dir = ensure_dir_path(component_root, file_def.path)
      if dest_dir then
        local filename = filename_template:gsub("__FILENAME__", name_text)
        local content = (content_template or ""):gsub("__COMPONENT_NAME__", name_text)
        local written = create_and_fill_file(dest_dir, filename, content)
        if written then
          table.insert(created, written)
        end
      end
    else
      core.error("[codegen] Skipping malformed component file entry (no filename key)")
    end
  end

  if #created > 0 then
    core.log("[codegen] Generated component \"%s\" in %s: %d file(s) created", name_text, component_root, #created)
  else
    core.error("[codegen] No files were created for component \"%s\"", name_text)
  end
end

-- Entry point, run from the treeview's folder context menu. Lets the user
-- pick a component (across every loaded module, since a component isn't
-- tied to a single file extension the way boilerplate is) and a name for
-- it, then creates its files under the right-clicked folder.
--
-- NOTE: user needs to provide only the details: es. name and attributes for Entity class
-- (attribute support isn't wired up yet -- current component definitions,
-- like modules/plainvanilla.lua's "base", only need a name. If a component
-- needs attributes too, extend the second command_view prompt below.)
local function generate_component()
  local target_dir = TreeView.hovered_item and TreeView.hovered_item.abs_filename
  if not target_dir or not fsutils.is_dir(target_dir) then
    core.error("[codegen] Generate Component must be run on a folder (right-click a folder in the tree view)")
    return
  end

  local candidates = {}
  for _, module in ipairs(modules) do
    if module.components then
      for _, comp in ipairs(module.components) do
        table.insert(candidates, {
          component = comp,
          label = module.name .. ": " .. comp.name
        })
      end
    end
  end

  if #candidates == 0 then
    core.error("[codegen] No components defined in any loaded module")
    return
  end

  core.command_view:enter("Component (module: name)", {
    submit = function(text)
      local chosen
      for _, c in ipairs(candidates) do
        if c.label == text then
          chosen = c
          break
        end
      end
      if not chosen then
        core.error("[codegen] Unknown component: %s", text)
        return
      end
      core.command_view:enter("Component name", {
        submit = function(name_text)
          generate_component_apply(target_dir, chosen.component, name_text)
        end
      })
    end,
    suggest = function(text)
      local res = {}
      for _, c in ipairs(candidates) do
        if c.label:find(text, 1, true) then
          table.insert(res, { text = c.label })
        end
      end
      return res
    end
  })
end

------------------
-- Context Menu --
------------------

local treeview_menu = TreeView.contextmenu
-- Check: is folder
treeview_menu:register(
  function()
    return
      TreeView.hovered_item
      and (
        fsutils.is_dir(TreeView.hovered_item.abs_filename) == true
        and TreeView.hovered_item.abs_filename ~= fsutils.project_dir()
      )
  end,
  {
    treeview_menu.DIVIDER,
    { text = "Test FOLDER", command = "code-generator:test-global-folder" },
    { text = "Generate Component", command = "code-generator:generate_component" },
  }
)
-- Check: is file
treeview_menu:register(
  function()
    return TreeView.hovered_item and fsutils.is_dir(TreeView.hovered_item.abs_filename) ~= true
  end, {
    treeview_menu.DIVIDER,
    { text = "Test FILE", command = "code-generator:test-global-file" },
    -- TODO: generate doc comments
  }
)

-- Check: is in DocView
local contextmenu = require "plugins.contextmenu"
contextmenu:register(
  "core.docview",
  {
    contextmenu.DIVIDER,
    { text = "Test DocView", command = "code-generator:test-global" },
    { text = "Wrap Selection", command = "code-generator:wrap-code-selection" },
    { text = "Generate Doc Comment", command = "code-generator:generate-doc-comment" },
    { text = "Generate Doc Comments (All)", command = "code-generator:generate-doc-comments" },
    -- TODO: functionality: add boilerplate (all vars/funcs by default, then remove the unneeded ones)
    -- TODO: functionality: update boilerplate (requires lsp+lsp-server integration)
  }
)

--------------
-- Commands --
--------------

-- NOTE: the plugin gets called from here...

-- Context: global
command.add(
  nil,
  {
    ["code-generator:test-global"] = test_global,
    ["code-generator:test-global-folder"] = test_global_folder,
    ["code-generator:test-global-file"] = test_global_file
  }
)

-- Context: current docview
-- NOTE: was `command.add(get_active_docview(), {...})`, which calls
-- get_active_docview() once at plugin-load time (when there's usually no
-- active docview yet) and binds the commands to that single fixed result
-- forever after. Passing the function itself (not its result) makes it a
-- proper predicate that's re-evaluated every time the command palette is
-- opened, which is what makes these commands reachable at all.
command.add(
  get_active_docview,
  {
    -- Test
    ["code-generator:test-in-doc"] = test_in_doc,
    -- Final
    ["code-generator:generate-boilerplate"] = generate_boilerplate,
    ["code-generator:wrap-code-selection"] = wrap_code_selection,
    ["code-generator:generate-doc-comment"] = generate_doc_comment,
    ["code-generator:generate-doc-comments"] = generate_doc_comments
  }
)

-- Context: treeview's context menu (files)
command.add(
  function()
    return TreeView.hovered_item and fsutils.is_dir(TreeView.hovered_item.abs_filename) ~= true
  end, {
    -- Test
    ["code-generator:test"] = test
  }
)

-- Context: treeview's context menu (folders)
-- NOTE: was bound to the same "is NOT a folder" predicate as the file
-- commands above, which made generate_component unreachable from a
-- folder right-click -- the only place it was ever wired into a menu.
command.add(
  function()
    return TreeView.hovered_item and fsutils.is_dir(TreeView.hovered_item.abs_filename) == true
  end, {
    ["code-generator:generate_component"] = generate_component
  }
)

-------
-- ? --
-------

core.add_thread(function() codegen.load() end)

return codegen
