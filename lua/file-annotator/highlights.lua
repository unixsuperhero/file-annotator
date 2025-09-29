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

function M.setup()
  -- Set up autocommands for refreshing highlights when entering buffers
  vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {
    callback = function()
      M.refresh_buffer()
    end,
    desc = "Refresh file annotator highlights"
  })
end

function M.create_highlight_group(layer_name, label_name, color)
  local group_name = "FileAnnotator_" .. layer_name .. "_" .. label_name

  vim.api.nvim_set_hl(0, group_name, {
    bg = color,
    fg = M.get_contrasting_color(color)
  })

  return group_name
end

function M.get_contrasting_color(hex_color)
  local r, g, b = hex_color:match("#(%x%x)(%x%x)(%x%x)")
  if not r then return "#000000" end

  r, g, b = tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
  local luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255

  return luminance > 0.5 and "#000000" or "#FFFFFF"
end

function M.apply_highlight(layer_name, label_name, line_num)
  if not state.layers[layer_name] or not state.layers[layer_name].visible then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local namespace = state.namespaces[layer_name]
  local group_name = "FileAnnotator_" .. layer_name .. "_" .. label_name

  -- Ensure highlight group exists
  if not state.layers[layer_name].labels[label_name] then
    return
  end

  M.create_highlight_group(layer_name, label_name, state.layers[layer_name].labels[label_name].color)

  vim.api.nvim_buf_add_highlight(bufnr, namespace, group_name, line_num - 1, 0, -1)
end

function M.refresh_buffer()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Clear all namespaces first
  for layer_name, namespace in pairs(state.namespaces) do
    vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  end

  -- Only show highlights for the current layer
  if state.current_layer and state.annotations[state.current_layer] then
    local layer_annotations = state.annotations[state.current_layer]
    for label_name, label_annotations in pairs(layer_annotations) do
      for line_num, annotation in pairs(label_annotations) do
        -- Defensive check: ensure annotation is a table with expected fields
        if type(annotation) == "table" and annotation.bufnr then
          if annotation.bufnr == bufnr then
            M.apply_highlight(state.current_layer, label_name, line_num)
          end
        else
          -- Handle corrupted annotation data
          vim.notify(string.format("Warning: Corrupted annotation data for layer '%s', label '%s', line %d. Removing.",
                                   state.current_layer, label_name, line_num), vim.log.levels.WARN)
          label_annotations[line_num] = nil
        end
      end
    end
  end
end

function M.refresh_buffer_all_layers()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Clear all namespaces first
  for layer_name, namespace in pairs(state.namespaces) do
    vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  end

  -- Reapply all annotations from all visible layers (for export/special cases)
  for layer_name, layer_annotations in pairs(state.annotations) do
    if state.layers[layer_name] and state.layers[layer_name].visible then
      for label_name, label_annotations in pairs(layer_annotations) do
        for line_num, annotation in pairs(label_annotations) do
          -- Defensive check: ensure annotation is a table with expected fields
          if type(annotation) == "table" and annotation.bufnr then
            if annotation.bufnr == bufnr then
              M.apply_highlight(layer_name, label_name, line_num)
            end
          else
            -- Handle corrupted annotation data
            vim.notify(string.format("Warning: Corrupted annotation data for layer '%s', label '%s', line %d. Removing.",
                                     layer_name, label_name, line_num), vim.log.levels.WARN)
            label_annotations[line_num] = nil
          end
        end
      end
    end
  end
end

function M.preview_color(layer_name, label_name, color)
  local bufnr = vim.api.nvim_get_current_buf()
  local line_num = vim.fn.line(".")

  -- Create temporary highlight group
  local temp_group = "FileAnnotatorPreview"
  vim.api.nvim_set_hl(0, temp_group, {
    bg = color,
    fg = M.get_contrasting_color(color)
  })

  -- Apply temporary highlight
  local temp_ns = vim.api.nvim_create_namespace("file_annotator_preview")
  vim.api.nvim_buf_add_highlight(bufnr, temp_ns, temp_group, line_num - 1, 0, -1)

  -- Remove after 2 seconds
  vim.defer_fn(function()
    vim.api.nvim_buf_clear_namespace(bufnr, temp_ns, 0, -1)
  end, 2000)
end

return M
