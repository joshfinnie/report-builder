--[[
Preamble composition, shared by every style.

build.sh used to pass the style preamble with --include-in-header. Pandoc
implements that flag by setting the `header-includes` template variable, and a
variable set on the command line beats the same field in a paper's YAML front
matter, so anything a paper put in `header-includes` was silently discarded.

This filter builds `header-includes` itself instead, in the order that lets the
later entries win:

  1. \def switches for the options below, so the style file can branch on them
  2. the style preamble named by `rb-style-preamble` (apa.tex / mla.tex)
  3. anything a style filter left in `rb-extra-preamble`
  4. the paper's own `header-includes`, last, so a paper can override the style

Options a paper may set in its front matter:

  pagenumber: topright | bottomright   (default topright)
  titlepage:  true | false             (default true)

Run this filter after the style filter, so `rb-extra-preamble` is already set.
--]]

local stringify = pandoc.utils.stringify

-- Options a paper sets in its front matter, mapped to the \def switches the
-- style files branch on with \ifdefined. `false` means "this is the default,
-- emit no switch"; it is stored rather than left nil so the valid choices can
-- still be listed back in an error message.
local SWITCHES = {
  pagenumber = {
    topright = false,
    bottomright = '\\rbPageNumberBottom',
  },
}

local function fail(msg)
  io.stderr:write('error: ' .. msg .. '\n')
  os.exit(1)
end

local function read_file(path)
  local fh = io.open(path, 'r')
  if not fh then fail('cannot read style preamble: ' .. path) end
  local body = fh:read('a')
  fh:close()
  return body
end

local function as_bool(value, default)
  if value == nil then return default end
  if type(value) == 'boolean' then return value end
  local text = stringify(value):lower()
  if text == 'true' or text == 'yes' then return true end
  if text == 'false' or text == 'no' then return false end
  fail('expected true or false, got: ' .. text)
end

-- Turn a metadata value into the blocks it contributes to the preamble.
-- Meta values arrive as Blocks/Inlines/List/string, not as MetaBlocks nodes,
-- so they are distinguished with pandoc.utils.type rather than a .t field.
local function to_blocks(value)
  if value == nil then return {} end
  local kind = pandoc.utils.type(value)
  if kind == 'Blocks' then
    local blocks = {}
    for _, block in ipairs(value) do table.insert(blocks, block) end
    return blocks
  end
  if kind == 'Inlines' then
    return { pandoc.Plain(value) }
  end
  if kind == 'List' then
    local blocks = {}
    for _, item in ipairs(value) do
      for _, block in ipairs(to_blocks(item)) do table.insert(blocks, block) end
    end
    return blocks
  end
  return { pandoc.RawBlock('latex', stringify(value)) }
end

local function switch_defs(meta)
  local defs = {}
  for option, choices in pairs(SWITCHES) do
    if meta[option] ~= nil then
      local choice = stringify(meta[option]):lower()
      local macro = choices[choice]
      if macro == nil then
        local names = {}
        for name in pairs(choices) do table.insert(names, name) end
        table.sort(names)
        fail(option .. ': unknown value "' .. choice ..
             '" (use ' .. table.concat(names, ' or ') .. ')')
      end
      if macro then table.insert(defs, '\\def' .. macro .. '{}') end
    end
  end
  if not as_bool(meta.titlepage, true) then
    table.insert(defs, '\\def\\rbNoTitlePage{}')
  end
  table.sort(defs)
  return defs
end

function Meta(meta)
  local path = meta['rb-style-preamble']
  if path == nil then return meta end

  local parts = {}
  local defs = switch_defs(meta)
  if #defs > 0 then
    table.insert(parts, pandoc.RawBlock('latex', table.concat(defs, '\n')))
  end
  table.insert(parts, pandoc.RawBlock('latex', read_file(stringify(path))))
  for _, block in ipairs(to_blocks(meta['rb-extra-preamble'])) do
    table.insert(parts, block)
  end
  for _, block in ipairs(to_blocks(meta['header-includes'])) do
    table.insert(parts, block)
  end

  meta['header-includes'] = pandoc.MetaBlocks(parts)
  meta['rb-style-preamble'] = nil
  meta['rb-extra-preamble'] = nil
  return meta
end
