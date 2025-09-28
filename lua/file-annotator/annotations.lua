local M = {}
local state = require("file-annotator").state

function M.annotate_line(line_num, label_name, layer_name)
  layer_name = layer_name or state.current_layer

  if not layer_name then
    vim.notify("No current layer set", vim.log.levels.ERROR)
    return false
  end

  -- Auto-create layer if it doesn't exist
  if not state.layers[layer_name] then
    local layers = require("file-annotator.layers")
    layers.create_layer(layer_name)
    vim.notify("Auto-created layer: " .. layer_name, vim.log.levels.INFO)
  end

  -- Auto-create label if it doesn't exist
  if not state.layers[layer_name].labels[label_name] then
    local layers = require("file-annotator.layers")
    layers.add_label(layer_name, label_name)
    vim.notify("Auto-created label '" .. label_name .. "' in layer '" .. layer_name .. "'", vim.log.levels.INFO)
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

  state.annotations[layer_name][label_name][line_num] = {
    bufnr = bufnr,
    filename = vim.api.nvim_buf_get_name(bufnr),
    timestamp = os.time()
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

  vim.notify("Cleared all annotations in layer: " .. layer_name, vim.log.levels.INFO)
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

  local success_count = 0
  for line_num = start_line, end_line do
    if M.annotate_line(line_num, label_name, layer_name) then
      success_count = success_count + 1
    end
  end

  vim.notify("Annotated " .. success_count .. " lines with label '" .. label_name .. "'", vim.log.levels.INFO)
  return success_count > 0
end

return M