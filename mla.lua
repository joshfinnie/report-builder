--[[
MLA 9 layout rules for pandoc, applied automatically so the markdown stays plain.

  1. The first paragraph of the document (the writer's heading: name,
     instructor, course and date) is set flush left, no first-line indent.
  2. A level-1 heading is the paper's title: centered, plain text, no bold
     and no section numbering.
  3. A table's number and title sit flush left above the table; a figure's
     "Fig. N." caption sits flush left below the image. Either way the
     image or table is kept together with its label across a page break.
  4. Tables are set small and single-spaced, which MLA allows for the
     table body, while the number, title and any source note outside it
     stay double-spaced.
  5. "Works Cited" and Appendix sections start on a new page.
  6. The `lastname:` front-matter field is pushed into the preamble as
     \mlaSurname, which mla.tex uses for the "Lastname #" running head.

Nothing here depends on a particular paper; build.sh passes it to every run.
--]]

local stringify = pandoc.utils.stringify

local function raw(s)
  return pandoc.RawBlock('latex', s)
end

-- A paragraph that is exactly a bold "Table 1" / "Fig. 1" label.
local function label_kind(block)
  if block.t ~= 'Para' or #block.content ~= 1 then return nil end
  local only = block.content[1]
  if only.t ~= 'Strong' then return nil end
  local text = stringify(only)
  if text:match('^Table%s+%w+%.?$') then return 'Table' end
  if text:match('^Fig%.?%s+%w+%.?$') then return 'Figure' end
  return nil
end

-- A paragraph that starts with a bold "Fig. N." label, followed by caption text.
local function is_fig_caption(block)
  if block.t ~= 'Para' or not block.content[1] then return false end
  local first = block.content[1]
  if first.t ~= 'Strong' then return false end
  return stringify(first):match('^Fig%.?%s+%w+%.?$') ~= nil
end

local function is_source_note(block)
  return block.t == 'Para' and stringify(block):match('^Source:')
end

local function is_image_para(block)
  if block.t ~= 'Para' then return false end
  for _, inline in ipairs(block.content) do
    if inline.t == 'Image' then return true end
  end
  return false
end

local function flush_left(block)
  if block.t == 'Para' then
    table.insert(block.content, 1, pandoc.RawInline('latex', '\\noindent{}'))
  end
  return block
end

-- Turn the paper's title heading into a centered, unstyled paragraph.
local function centered_title(header)
  local para = pandoc.Para(header.content)
  table.insert(para.content, 1, pandoc.RawInline('latex', '\\begin{center}\\noindent{}'))
  table.insert(para.content, pandoc.RawInline('latex', '\\end{center}'))
  return para
end

-- LaTeX specials that could appear in a surname, e.g. O'Brien-Smith is fine but
-- a stray & or _ would otherwise break the preamble.
local function latex_escape(text)
  return (text:gsub('[\\{}#$%%&_~^]', {
    ['\\'] = '\\textbackslash{}',
    ['{'] = '\\{', ['}'] = '\\}',
    ['#'] = '\\#', ['$'] = '\\$', ['%'] = '\\%', ['&'] = '\\&',
    ['_'] = '\\_', ['~'] = '\\textasciitilde{}',
    ['^'] = '\\textasciicircum{}',
  }))
end

-- mla.tex declares \mlaSurname empty; this defines it from the paper's front
-- matter. It is emitted as the first block of the body rather than via
-- header-includes, because build.sh passes mla.tex with --include-in-header,
-- which sets the header-includes template variable and shadows any metadata
-- field of the same name. \mlaSurname is only expanded when a page ships out,
-- so defining it ahead of the first paragraph covers every page.
local function surname_def(meta)
  local surname = meta.lastname and stringify(meta.lastname) or ''
  if surname == '' then
    io.stderr:write(
      "add 'lastname: \"Surname\"' to the paper's front matter for the MLA header\n")
    os.exit(1)
  end
  return raw('\\renewcommand{\\mlaSurname}{' .. latex_escape(surname) .. '}')
end

function Pandoc(doc)
  local out = { surname_def(doc.meta) }
  local blocks = doc.blocks
  local i = 1
  local seen_heading = false

  while i <= #blocks do
    local block = blocks[i]
    local kind = label_kind(block)

    if not seen_heading and block.t == 'Para' then
      table.insert(out, flush_left(block))
      seen_heading = true
      i = i + 1

    elseif block.t == 'Header' and block.level == 1 then
      table.insert(out, centered_title(block))
      i = i + 1

    elseif is_image_para(block) then
      -- Reserve room so the image and its caption below stay together.
      table.insert(out, raw('\\needspace{6\\baselineskip}'))
      table.insert(out, flush_left(block))
      i = i + 1
      if blocks[i] and is_fig_caption(blocks[i]) then
        table.insert(out, flush_left(blocks[i]))
        i = i + 1
      end

    elseif kind == 'Table' then
      -- Reserve room so the number, title and the start of the table stay together.
      table.insert(out, raw('\\needspace{6\\baselineskip}'))
      table.insert(out, flush_left(block))
      i = i + 1
      -- A plain title paragraph belongs with the label, flush left as well.
      if blocks[i] and blocks[i].t == 'Para' and not is_image_para(blocks[i])
        and not is_source_note(blocks[i]) and not label_kind(blocks[i]) then
        table.insert(out, flush_left(blocks[i]))
        i = i + 1
      end

    elseif is_source_note(block) then
      table.insert(out, flush_left(block))
      i = i + 1

    elseif block.t == 'Table' then
      table.insert(out, raw('\\begingroup\\small\\singlespacing\\setlength{\\tabcolsep}{4pt}'))
      table.insert(out, block)
      table.insert(out, raw('\\endgroup'))
      i = i + 1

    elseif block.t == 'Header' and
           (stringify(block) == 'Works Cited' or stringify(block):match('^Appendix')) then
      table.insert(out, raw('\\newpage'))
      table.insert(out, block)
      i = i + 1

    else
      table.insert(out, block)
      i = i + 1
    end
  end

  doc.blocks = out
  return doc
end
