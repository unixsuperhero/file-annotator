local M = {}
local state = require("file-annotator").state

function M.setup()
  -- Set up autocommands for refreshing highlights when entering buffers
  vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {
    callback = function()
      M.refresh_buffer()
    end,
    desc = "Refresh file annotator highlights"
  })
end

function M.create_highlight_group(label_name, color)
  local group_name = "FileAnnotator_" .. label_name

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

function M.apply_highlight(label_name, line_num, col_start, col_end)
  if not state.labels[label_name] then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local namespace = state.namespace
  local group_name = "FileAnnotator_" .. label_name

  M.create_highlight_group(label_name, state.labels[label_name].color)

  -- Apply highlight with column range if specified
  if col_start and col_end then
    vim.api.nvim_buf_add_highlight(bufnr, namespace, group_name, line_num - 1, col_start, col_end)
  else
    vim.api.nvim_buf_add_highlight(bufnr, namespace, group_name, line_num - 1, 0, -1)
  end
end

function M.refresh_buffer()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Clear namespace
  vim.api.nvim_buf_clear_namespace(bufnr, state.namespace, 0, -1)

  -- Reapply all annotations
  for label_name, label_annotations in pairs(state.annotations) do
    for line_num, line_data in pairs(label_annotations) do
      if type(line_data) == "table" then
        -- New format: multiple annotations per line
        for annotation_id, annotation in pairs(line_data) do
          if type(annotation) == "table" and annotation.bufnr == bufnr then
            M.apply_highlight(label_name, line_num, annotation.col_start, annotation.col_end)
          end
        end
      end
    end
  end
end

function M.preview_color(label_name, color)
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
