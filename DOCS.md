# Documentation

```lua
local current_docview = get_active_docview()
```

## 1. Print some Doc data

```lua
core.log(common.serialize(current_docview.doc.lines)) Print lines
core.log(current_docview.doc.filename) Print filename
core.log(current_docview.doc.abs_filename) Print absolute filename
```

## 2.1. Move caret to new position

```lua
local x, y = current_docview.doc:position_offset(1, 2, 2, 3) Calculate new position for caret
current_docview.doc:set_selection(x, y) Move the caret to new position
```

## 2.2. Set selection

```lua
current_docview.doc:set_selection(1, 1, 1, 10) Select from (1,1) to (1,10)
```

## 3. Replace tag with text

```lua
single-line string
local text = current_docview.doc:get_text(1,1,10,10) Gets text between 1,1 and 10,10 (row,col)
core.log(common.serialize(text))
current_docview.doc:text_input("Hello there!")
current_docview.doc:insert(1, 1, "\n" .. textt .. "\n")
```

## 4. Get selection and replace it with text

```lua
local line1, col1, line2, col2 = current_docview.doc:get_selection()
if line1 ~= line2 or col1 ~= col2 then
  local selected_text = current_docview.doc:get_text(line1, col1, line2, col2)
  core.log("Selected text: " .. selected_text)
  current_docview.doc:remove(line1, col1, line2, col2)
  current_docview.doc:insert(line1, col1, "REPLACED TEXT HERE")
  current_docview.doc:insert(line1, col1, textt)
else
  core.log("No text selected, just a cursor position")
end
```

## 5. same, multiple selections, handle at the same time

```lua
if current_docview.doc:has_any_selection() then
  current_docview.doc:replace(function(text)
    core.log("Replacing: " .. text)
    return textt
  end)
else
  core.log("No selections found")
end
```

## 6. same, multiple selections, handle one at a time

```lua
NOTE: use this to wrap for try-catch...
local selections = {}
for idx, line1, col1, line2, col2 in current_docview.doc:get_selections(true) do Collect all selections first
  if line1 ~= line2 or col1 ~= col2 then
    local text = current_docview.doc:get_text(line1, col1, line2, col2)
    table.insert(selections, {
      idx = idx,
      line1 = line1, col1 = col1,
      line2 = line2, col2 = col2,
      text = text
    })
  end
end
for i = #selections, 1, -1 do Process each selection (process in reverse to maintain positions)
  local sel = selections[i]
  core.log("Selection " .. sel.idx .. ": " .. sel.text)
  Replace with your custom text
  local replacement = "<<" .. sel.text:upper() .. ">>"  Example: wrap in brackets and uppercase
  current_docview.doc:remove(sel.line1, sel.col1, sel.line2, sel.col2)
  current_docview.doc:insert(sel.line1, sel.col1, replacement)
end
```

## 7. Get selected text and replace pattern within with some text

```lua
local tag7 = "ELSE"
local replacement7 = "REPLACED TEXT HERE"
local line1, col1, line2, col2 = current_docview.doc:get_selection()
if line1 ~= line2 or col1 ~= col2 then Check that selection is 1. multi-line string or 2. is not empty
  local selected_text = current_docview.doc:get_text(line1, col1, line2, col2)
  core.log("Selected text: " .. selected_text)
  if string.find(selected_text, tag7) then
    current_docview.doc:remove(line1, col1, line2, col2)
    local new_text = string.gsub(selected_text, tag7, replacement7)
    current_docview.doc:insert(line1, col1, new_text)
  end
else
  core.log("No text selected, just a cursor position")
end
```

## 8. Get selected text with matched string and add some text above it

```lua
local tag8 = "ELSE"
local line1, col1, line2, col2 = current_docview.doc:get_selection()
if line1 ~= line2 or col1 ~= col2 then Check that selection is 1. multi-line string or 2. is not empty
  local selected_text = current_docview.doc:get_text(line1, col1, line2, col2)
  core.log("Selected text: " .. selected_text)
  local indent = current_docview.doc.lines[line1]:match("^%s*") or ""
  if string.find(selected_text, tag8) then
    current_docview.doc:remove(line1, col1, line2, col2)
    core.log(common.serialize(selected_text))
    local new_text = string.gsub(selected_text, tag8, "REPLACED TEXT HERE")
    By adding indent before new_text I can just select the text and not also the indentation!
    local modified_text = ""
    if indent == "" or selected_text:match("^%s*") == "" then
      modified_text = "This is the string above the selection" .. "\n" ..
                      indent .. new_text
    else
      modified_text = indent .. "This is the string above the selection" .. "\n" ..
                      new_text
    end
    current_docview.doc:insert(line1, col1, modified_text)
  end
else
  core.log("No text selected, just a cursor position")
end

9. Get selected text with matched string and add some text beneath it:
same as above but the "\n" goes after the new_text and before the beneath_text
NOTE: for wrapping code blocks, add one more level of indentation to all lines
```
