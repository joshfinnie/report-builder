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

  pagenumber: topright | bottomright              (default topright)
  titlepage:  student | professional | false      (default student; true is
                                                   a synonym for student)
  shorttitle: the running head APA 7's professional title page carries
  font:       one of the APA 7 approved fonts, which sets family and size
              together (see FONTS below)

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
  titlepage = {
    ['true'] = false,
    student = false,
    professional = '\\rbProfessionalTitlePage',
    ['false'] = '\\rbNoTitlePage',
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

local function as_text(value)
  if type(value) == 'boolean' then return tostring(value) end
  return stringify(value)
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

-- The fonts APA 7 allows, each with the size it is approved at. A paper picks
-- one by name with `font:` and gets both, since APA pairs them: Georgia is
-- approved at 11pt, not at 12pt.
--
-- `family = false` means the style uses LaTeX's own font. Computer Modern is
-- not a system font, and leaving mainfont unset is what selects it.
local FONTS = {
  arial             = { family = 'Arial',               size = '11pt' },
  aptos             = { family = 'Aptos',               size = '12pt' },
  calibri           = { family = 'Calibri',             size = '11pt' },
  ['lucida-sans']   = { family = 'Lucida Sans Unicode', size = '10pt' },
  georgia           = { family = 'Georgia',             size = '11pt' },
  times             = { family = 'Times New Roman',     size = '12pt' },
  ['computer-modern'] = { family = false,               size = '10pt' },
}

local function font_names()
  local names = {}
  for name in pairs(FONTS) do table.insert(names, name) end
  table.sort(names)
  return table.concat(names, ', ')
end

local function preset(value, source)
  local name = as_text(value):lower()
  local found = FONTS[name]
  if found == nil then
    fail(source .. ': unknown font "' .. name .. '" (use one of: ' .. font_names() .. ')')
  end
  return found
end

-- Resolve the font, most specific last:
--
--   1. `font:` in the paper, which fills in whatever the paper did not set
--      itself, so an explicit mainfont: or fontsize: still wins
--   2. --font on the command line, which replaces both
--   3. --font-family / --font-size, which replace one each
--
-- build.sh passes the command-line forms under rb- names precisely so they can
-- be applied after the paper's own metadata rather than before it.
local function apply_font(meta)
  if meta.font ~= nil then
    local chosen = preset(meta.font, 'font')
    if meta.mainfont == nil and chosen.family then
      meta.mainfont = pandoc.MetaString(chosen.family)
    end
    if meta.fontsize == nil then
      meta.fontsize = pandoc.MetaString(chosen.size)
    end
  end

  if meta['rb-font'] ~= nil then
    local chosen = preset(meta['rb-font'], '--font')
    meta.mainfont = chosen.family and pandoc.MetaString(chosen.family) or nil
    meta.fontsize = pandoc.MetaString(chosen.size)
  end

  if meta['rb-mainfont'] ~= nil then
    meta.mainfont = pandoc.MetaString(as_text(meta['rb-mainfont']))
  end
  if meta['rb-fontsize'] ~= nil then
    meta.fontsize = pandoc.MetaString(as_text(meta['rb-fontsize']))
  end

  meta['rb-font'] = nil
  meta['rb-mainfont'] = nil
  meta['rb-fontsize'] = nil
  return meta
end

-- LaTeX specials that could appear in a title or short title.
local function latex_escape(text)
  return (text:gsub('[\\{}#$%%&_~^]', {
    ['\\'] = '\\textbackslash{}',
    ['{'] = '\\{', ['}'] = '\\}',
    ['#'] = '\\#', ['$'] = '\\$', ['%'] = '\\%', ['&'] = '\\&',
    ['_'] = '\\_', ['~'] = '\\textasciitilde{}',
    ['^'] = '\\textasciicircum{}',
  }))
end

-- APA 7's professional title page carries a running head: the short title in
-- capitals, flush left. It comes from `shorttitle:` when the paper sets one and
-- from the title otherwise. APA caps it at 50 characters.
--
-- Emitted only for that title page, and with \def so it stands on its own: a
-- style file that never uses a running head does not have to declare the macro.
local function short_title_def(meta)
  if meta.titlepage == nil then return nil end
  if as_text(meta.titlepage):lower() ~= 'professional' then return nil end
  local source = meta.shorttitle or meta.title
  if source == nil then return nil end
  local text = as_text(source):upper()
  if #text > 50 then text = text:sub(1, 50) end
  return pandoc.RawBlock('latex', '\\def\\rbShortTitle{' .. latex_escape(text) .. '}')
end

local function switch_defs(meta)
  local defs = {}
  for option, choices in pairs(SWITCHES) do
    if meta[option] ~= nil then
      local choice = as_text(meta[option]):lower()
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
  table.sort(defs)
  return defs
end

function Meta(meta)
  meta = apply_font(meta)

  local path = meta['rb-style-preamble']
  if path == nil then return meta end

  local parts = {}
  local defs = switch_defs(meta)
  if #defs > 0 then
    table.insert(parts, pandoc.RawBlock('latex', table.concat(defs, '\n')))
  end
  table.insert(parts, pandoc.RawBlock('latex', read_file(stringify(path))))
  local short = short_title_def(meta)
  if short then table.insert(parts, short) end
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
