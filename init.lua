-- mod-version:3
local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local TreeView = require "plugins.treeview"
local DocView = require "core.docview"

local fsutils = require "plugins.codegen.fsutils"

-- TODO: allows updating boilerplate code
--       (run command -> check if boilerplate already exists -> update it)
--       (or also remove boilerplate containing unknown names)

-- TODO: component generation
--       (es. java: entity class, bastano il nome della class, che contiene il percorso relativo)
--       (e i nomi degli attributi/campi)
--       (usa comando e context menu)

-- TODO: add cli code doc generators (es. jautodoc for Java, ...) integration
--       (es. generate documentation comments for all elements of a source file)

-----------------------------------------
-- NOTES ON MANIPULATING SELECTED TEXT --
-----------------------------------------

-- local current_docview = get_active_docview()

-- 1. Print some Doc data
-- core.log(common.serialize(current_docview.doc.lines)) -- Print lines
-- core.log(current_docview.doc.filename) -- Print filename
-- core.log(current_docview.doc.abs_filename) -- Print absolute filename

-- 2.1. Move caret to new position
-- local x, y = current_docview.doc:position_offset(1, 2, 2, 3) -- Calculate new position for caret
-- current_docview.doc:set_selection(x, y) -- Move the caret to new position

-- 2.2. Set selection
-- current_docview.doc:set_selection(1, 1, 1, 10) -- Select from (1,1) to (1,10)

-- 3. Replace tag with text
-- single-line string
-- local text = current_docview.doc:get_text(1,1,10,10) -- Gets text between 1,1 and 10,10 (row,col)
-- core.log(common.serialize(text))
-- current_docview.doc:text_input("Hello there!")
-- current_docview.doc:insert(1, 1, "\n" .. textt .. "\n")

-- 4. Get selection and replace it with text
-- local line1, col1, line2, col2 = current_docview.doc:get_selection()
-- if line1 ~= line2 or col1 ~= col2 then
--   local selected_text = current_docview.doc:get_text(line1, col1, line2, col2)
--   core.log("Selected text: " .. selected_text)
--   current_docview.doc:remove(line1, col1, line2, col2)
--   -- current_docview.doc:insert(line1, col1, "REPLACED TEXT HERE")
--   current_docview.doc:insert(line1, col1, textt)
-- else
--   core.log("No text selected, just a cursor position")
-- end

-- 5. same, multiple selections, handle at the same time
-- if current_docview.doc:has_any_selection() then
--   current_docview.doc:replace(function(text)
--     core.log("Replacing: " .. text)
--     return textt
--   end)
-- else
--   core.log("No selections found")
-- end

-- 6. same, multiple selections, handle one at a time
-- NOTE: use this to wrap for try-catch...
-- local selections = {}
-- for idx, line1, col1, line2, col2 in current_docview.doc:get_selections(true) do -- Collect all selections first
--   if line1 ~= line2 or col1 ~= col2 then
--     local text = current_docview.doc:get_text(line1, col1, line2, col2)
--     table.insert(selections, {
--       idx = idx,
--       line1 = line1, col1 = col1,
--       line2 = line2, col2 = col2,
--       text = text
--     })
--   end
-- end
-- for i = #selections, 1, -1 do -- Process each selection (process in reverse to maintain positions)
--   local sel = selections[i]
--   core.log("Selection " .. sel.idx .. ": " .. sel.text)
--   -- Replace with your custom text
--   local replacement = "<<" .. sel.text:upper() .. ">>"  -- Example: wrap in brackets and uppercase
--   current_docview.doc:remove(sel.line1, sel.col1, sel.line2, sel.col2)
--   current_docview.doc:insert(sel.line1, sel.col1, replacement)
-- end

-- 7. Get selected text and replace pattern within with some text
-- local tag7 = "ELSE"
-- local replacement7 = "REPLACED TEXT HERE"
-- local line1, col1, line2, col2 = current_docview.doc:get_selection()
-- if line1 ~= line2 or col1 ~= col2 then -- Check that selection is 1. multi-line string or 2. is not empty
--   local selected_text = current_docview.doc:get_text(line1, col1, line2, col2)
--   core.log("Selected text: " .. selected_text)
--   if string.find(selected_text, tag7) then
--     current_docview.doc:remove(line1, col1, line2, col2)
--     local new_text = string.gsub(selected_text, tag7, replacement7)
--     current_docview.doc:insert(line1, col1, new_text)
--   end
-- else
--   core.log("No text selected, just a cursor position")
-- end

-- 8. Get selected text with matched string and add some text above it
-- local tag8 = "ELSE"
-- local line1, col1, line2, col2 = current_docview.doc:get_selection()
-- if line1 ~= line2 or col1 ~= col2 then -- Check that selection is 1. multi-line string or 2. is not empty
--   local selected_text = current_docview.doc:get_text(line1, col1, line2, col2)
--   core.log("Selected text: " .. selected_text)
--   local indent = current_docview.doc.lines[line1]:match("^%s*") or ""
--   if string.find(selected_text, tag8) then
--     current_docview.doc:remove(line1, col1, line2, col2)
--     core.log(common.serialize(selected_text))
--     local new_text = string.gsub(selected_text, tag8, "REPLACED TEXT HERE")
--     -- By adding indent before new_text I can just select the text and not also the indentation!
--     local modified_text = ""
--     if indent == "" or selected_text:match("^%s*") == "" then
--       modified_text = "-- This is the string above the selection" .. "\n" ..
--                       indent .. new_text
--     else
--       modified_text = indent .. "-- This is the string above the selection" .. "\n" ..
--                       new_text
--     end
--     current_docview.doc:insert(line1, col1, modified_text)
--   end
-- else
--   core.log("No text selected, just a cursor position")
-- end

-- 9. Get selected text with matched string and add some text beneath it:
-- same as above but the "\n" goes after the new_text and before the beneath_text
-- NOTE: for wrapping code blocks, add one more level of indentation to all lines

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

-- NOTE: returns table on first match
local function select_module(file_extension)
  for _, module in ipairs(modules) do
  	for _, extension in ipairs(module.file_extensions) do
  	  if extension == file_extension then
  	    return common.serialize(module)
  	  end
  	end
  end
end

-- Automatic FILE FILL of New Named Doc
local old_open_doc = core.open_doc -- Get old function content
-- Extend old function
function core.open_doc(filename, ...)
  -- New file check (to avoid writing in the file every time it's opened)
  local file_exists = system.get_file_info(filename) ~= nil
  -- Inherit old function content
  local doc = old_open_doc(filename, ...)
  -- New logic
  -- TODO: draw commandview to select file fill type
  local file_extension = string.match(filename, "%.%a+$")
  local selected_module = select_module(file_extension)
  -- FIX: returned module is missing pieces ?
  -- print(selected_module)
  -- WIP: get package path for new Java file, set it and write it (get the pkg path root from the properties table)
  if doc.filename == filename and not file_exists then
  	if string.find(doc.filename, file_extension) then
      -- FIX: ?
      for _, file_fill in ipairs(selected_module.file_fills) do
        doc:insert(1, 1, file_fill)
      end
    end
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

local function create_folder(folder_path, folder_name)
  -- copy from lite-lx-codegen
end

local function create_and_fill_file(file_path, file_name, file_content)
  -- copy from lite-lx-codegen
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
local function generate_boilerplate()
	-- TODO: get current doc's file extension
	-- TODO: determine which module table to use
	-- TODO: call generate_text_in_file()
	-- TODO: open commandview...
	-- TODO: if table type is "getter" or "setter", check for the boolean "is_oneliner"
end

-- TODO: Wrap code selection (context: current doc, command),
--       wrap selected code (es. try-catch-finally, ...),
--       add items to Doc context menu
--       1. get selection
--       2. add lines, add one indent to selected code
--       3. replace selection
local function wrap_code_selection()
	-- TODO: open commandview...
	-- TODO: temporary base logic
	
end

-- TODO: command to auto-generate doc comments for selected symbol
-- TODO: command to auto-generate doc comments for all symbols in current doc (?)
-- TODO: command to auto-generate doc comments for all project file (es. all .java files in project folder) (?)
--       1. get position of start of line above selection
--       2. insert text at that position plus empty line above
-- TODO: check that symbol doesn't already have doc comments above
local function generate_doc_comment()
	-- TODO: get selected symbol from lsp
	-- TODO: write doc comment
end

local function generate_doc_comments()
	-- TODO: get list of current doc symbols
	-- TODO: call generate_doc_comment for each of them
end

-- NOTE: user needs to provide only the details: es. name and attributes for Entity class
local function generate_component()
  -- TODO: after clicking on treview item, open commandview to input the component's details (name, ...)
  -- TODO: get destination path and component details
  -- TODO: create folder ?
  -- TODO: create and fill files
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
    -- TODO: add component
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
command.add(
  get_active_docview(),
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

-- Context: treeview's context menu
command.add(
  function()
    return TreeView.hovered_item and fsutils.is_dir(TreeView.hovered_item.abs_filename) ~= true
  end, {
    -- Test
    ["code-generator:test"] = test,
    -- Final
    ["code-generator:generate_component"] = generate_component
  }
)

-------
-- ? --
-------

core.add_thread(function() codegen.load() end)

return codegen
