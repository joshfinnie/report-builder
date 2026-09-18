--[[
APA 7 layout rules for pandoc, applied automatically so the markdown stays plain.

  1. Table/Figure numbers, their italic titles, Note lines and images are flush
     left. (Body paragraphs keep their first-line indent.)
  2. A figure's number, title and image are wrapped in a minipage so a page
     break can never separate them.
  3. Tables are set small and single-spaced, which APA allows for the table
     body, while the number, title and note stay double-spaced outside.
  4. References and Appendix start on a new page.

Nothing here depends on a particular paper; build.sh passes it to every run.
--]]

local stringify = pandoc.utils.stringify

local function raw(s)
  return pandoc.RawBlock('latex', s)
end

-- A paragraph that is exactly a bold "Table 1" / "Figure A2" label.
local function label_kind(block)
  if block.t ~= 'Para' or #block.content ~= 1 then return nil end
  local only = block.content[1]
  if only.t ~= 'Strong' then return nil end
  local kind = stringify(only):match('^(%a+)%s+%w+$')
  if kind == 'Table' or kind == 'Figure' then return kind end
  return nil
end

local function is_emph_para(block)
  return block.t == 'Para' and block.content[1] and block.content[1].t == 'Emph'
end

local function is_note(block)
  return block.t == 'Para' and stringify(block):match('^Note%.')
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
    table.insert(block.content, 1, pandoc.RawInline('latex', '\\noindent'))
  end
  return block
end

function Pandoc(doc)
  local out = {}
  local i = 1
  local blocks = doc.blocks

  while i <= #blocks do
    local block = blocks[i]
    local kind = label_kind(block)

    if kind == 'Figure' then
      -- Collect the label, an optional italic title, and the image.
      local group = { flush_left(block) }
      local j = i + 1
      while j <= #blocks do
        local nxt = blocks[j]
        if is_emph_para(nxt) or is_image_para(nxt) then
          table.insert(group, flush_left(nxt))
          j = j + 1
          if is_image_para(nxt) then break end
        else
          break
        end
      end
      table.insert(out, raw('\\noindent\\begin{minipage}{\\linewidth}'))
      for _, b in ipairs(group) do table.insert(out, b) end
      table.insert(out, raw('\\end{minipage}'))
      i = j

    elseif kind == 'Table' then
      -- Reserve room so the number, title and the start of the table stay together.
      table.insert(out, raw('\\needspace{6\\baselineskip}'))
      table.insert(out, flush_left(block))
      i = i + 1
      -- The italic title belongs with the label, flush left as well.
      if blocks[i] and is_emph_para(blocks[i]) then
        table.insert(out, flush_left(blocks[i]))
        i = i + 1
      end

    elseif is_note(block) or is_image_para(block) then
      table.insert(out, flush_left(block))
      i = i + 1

    elseif block.t == 'Table' then
      table.insert(out, raw('\\begingroup\\small\\singlespacing\\setlength{\\tabcolsep}{4pt}'))
      table.insert(out, block)
      table.insert(out, raw('\\endgroup'))
      i = i + 1

    elseif block.t == 'Header' and
           (stringify(block) == 'References' or stringify(block):match('^Appendix')) then
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
