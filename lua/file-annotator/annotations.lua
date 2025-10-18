local M = {}
local state = require("file-annotator").state

-- Helper function for silent messaging
local function silent_message(msg, level)
  level = level or vim.log.levels.INFO

  -- Split multi-line messages and handle each line separately
  local lines = vim.split(msg, "\n", { plain = true })

  for _, line in ipairs(lines) do
    -- Escape single quotes by doubling them
    local escaped_line = line:gsub("'", "''")

    if level == vim.log.levels.ERROR then
      vim.cmd("silent echohl ErrorMsg")
      vim.cmd(string.format("silent echom '%s'", escaped_line))
      vim.cmd("silent echohl None")
    elseif level == vim.log.levels.WARN then
      vim.cmd("silent echohl WarningMsg")
      vim.cmd(string.format("silent echom '%s'", escaped_line))
      vim.cmd("silent echohl None")
    else
      vim.cmd(string.format("silent echom '%s'", escaped_line))
    end
  end
end

function M.annotate_line(line_num, label_name, layer_name, col_start, col_end)
  layer_name = layer_name or state.current_layer

  if not layer_name then
    vim.notify("No current layer set and no layer specified", vim.log.levels.ERROR)
    return false
  end

  local layers = require("file-annotator.layers")

  -- Auto-create layer if it doesn't exist
  if not state.layers[layer_name] then
    layers.create_layer(layer_name)
    silent_message("Auto-created layer: " .. layer_name, vim.log.levels.INFO)
  end

  -- Auto-switch to the layer if it's not the current one
  if state.current_layer ~= layer_name then
    state.current_layer = layer_name
    require("file-annotator.highlights").refresh_buffer()
    silent_message("Switched to layer: " .. layer_name, vim.log.levels.INFO)
  end

  -- Auto-create label if it doesn't exist
  if not state.layers[layer_name].labels[label_name] then
    layers.add_label(layer_name, label_name)
    silent_message("Auto-created label '" .. label_name .. "' in layer '" .. layer_name .. "'", vim.log.levels.INFO)
  end

  if not state.annotations[layer_name] then
    state.annotations[layer_name] = {}
  end

  if not state.annotations[layer_name][label_name] then
    state.annotations[layer_name][label_name] = {}
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  if line_num < 1 or line_num > line_count then
    vim.notify("Line number " .. line_num .. " is out of range", vim.log.levels.ERROR)
    return false
  end

  -- Validate column range if provided
  if col_start and col_end then
    local line_content = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1]
    local line_length = #line_content
    if col_start < 0 or col_end > line_length or col_start >= col_end then
      vim.notify("Invalid column range", vim.log.levels.ERROR)
      return false
    end
  end

  if not state.annotations[layer_name][label_name][line_num] then
    state.annotations[layer_name][label_name][line_num] = {}
  end

  -- Generate unique ID for this annotation
  local annotation_id = os.time() .. "_" .. math.random(1000, 9999)

  state.annotations[layer_name][label_name][line_num][annotation_id] = {
    bufnr = bufnr,
    filename = vim.api.nvim_buf_get_name(bufnr),
    timestamp = os.time(),
    col_start = col_start,
    col_end = col_end
  }

  require("file-annotator.highlights").apply_highlight(layer_name, label_name, line_num)
  return true
end

function M.remove_annotation(line_num, label_name, layer_name)
  layer_name = layer_name or state.current_layer

  if not layer_name then
    vim.notify("No current layer set", vim.log.levels.ERROR)
    return false
  end

  if not state.annotations[layer_name] or
     not state.annotations[layer_name][label_name] or
     not state.annotations[layer_name][label_name][line_num] then
    vim.notify("No annotation found at line " .. line_num, vim.log.levels.WARN)
    return false
  end

  state.annotations[layer_name][label_name][line_num] = nil

  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, state.namespaces[layer_name], line_num - 1, line_num)

  return true
end

function M.toggle_annotation(line_num, label_name, layer_name)
  layer_name = layer_name or state.current_layer

  if state.annotations[layer_name] and
     state.annotations[layer_name][label_name] and
     state.annotations[layer_name][label_name][line_num] then
    return M.remove_annotation(line_num, label_name, layer_name)
  else
    return M.annotate_line(line_num, label_name, layer_name)
  end
end

function M.clear_all_annotations(layer_name)
  layer_name = layer_name or state.current_layer

  if not layer_name then
    vim.notify("No current layer set", vim.log.levels.ERROR)
    return false
  end

  if state.annotations[layer_name] then
    state.annotations[layer_name] = {}
  end

  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, state.namespaces[layer_name], 0, -1)

  silent_message("Cleared all annotations in layer: " .. layer_name, vim.log.levels.INFO)
  return true
end

function M.get_line_annotations(line_num)
  local annotations = {}

  for layer_name, layer_annotations in pairs(state.annotations) do
    for label_name, label_annotations in pairs(layer_annotations) do
      if label_annotations[line_num] then
        table.insert(annotations, {
          layer = layer_name,
          label = label_name,
          color = state.layers[layer_name].labels[label_name].color
        })
      end
    end
  end

  return annotations
end

function M.get_all_annotations()
  return state.annotations
end

function M.annotate_selection(label_name, layer_name)
  layer_name = layer_name or state.current_layer

  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")
  local start_col = vim.fn.col("'<") - 1  -- Convert to 0-based
  local end_col = vim.fn.col("'>")  -- Inclusive end
  local mode = vim.fn.visualmode()

  local success_count = 0

  -- Handle character-wise visual selection
  if mode == 'v' then
    if start_line == end_line then
      -- Single line character selection
      if M.annotate_line(start_line, label_name, layer_name, start_col, end_col) then
        success_count = success_count + 1
        silent_message("Annotated character range (cols " .. start_col .. "-" .. end_col .. ") with label '" .. label_name .. "'", vim.log.levels.INFO)
      end
    else
      -- Multi-line character selection - annotate each line with appropriate column ranges
      for line_num = start_line, end_line do
        local col_s, col_e
        if line_num == start_line then
          col_s = start_col
          col_e = nil  -- To end of line
        elseif line_num == end_line then
          col_s = 0  -- From start of line
          col_e = end_col
        else
          col_s = nil  -- Whole line
          col_e = nil
        end

        if M.annotate_line(line_num, label_name, layer_name, col_s, col_e) then
          success_count = success_count + 1
        end
      end
      silent_message("Annotated " .. success_count .. " lines with label '" .. label_name .. "'", vim.log.levels.INFO)
    end
  else
    -- Line-wise or block-wise visual selection - annotate whole lines
    for line_num = start_line, end_line do
      if M.annotate_line(line_num, label_name, layer_name) then
        success_count = success_count + 1
      end
    end
    silent_message("Annotated " .. success_count .. " lines with label '" .. label_name .. "'", vim.log.levels.INFO)
  end

  return success_count > 0
end

function M.annotate_range(start_line, end_line, label_name, layer_name)
  if not start_line or not end_line then
    vim.notify("Invalid range specified", vim.log.levels.ERROR)
    return false
  end

  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  local success_count = 0
  for line_num = start_line, end_line do
    if M.annotate_line(line_num, label_name, layer_name) then
      success_count = success_count + 1
    end
  end

  if success_count > 1 then
    silent_message("Annotated " .. success_count .. " lines (lines " .. start_line .. "-" .. end_line .. ") with label '" .. label_name .. "'", vim.log.levels.INFO)
  end
  return success_count > 0
end

return M
