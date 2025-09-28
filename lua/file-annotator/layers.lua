local M = {}
local state = require("file-annotator").state
local config = require("file-annotator").config

function M.create_layer(name)
  if not name or name == "" then
    vim.notify("Layer name cannot be empty", vim.log.levels.ERROR)
    return false
  end

  if state.layers[name] then
    vim.notify("Layer '" .. name .. "' already exists", vim.log.levels.WARN)
    return false
  end

  state.layers[name] = {
    labels = {},
    visible = true,
    created_at = os.time()
  }

  state.namespaces[name] = vim.api.nvim_create_namespace("file_annotator_" .. name)

  if not state.current_layer then
    state.current_layer = name
  end

  vim.notify("Created layer: " .. name, vim.log.levels.INFO)
  return true
end

function M.delete_layer(name)
  if not state.layers[name] then
    vim.notify("Layer '" .. name .. "' does not exist", vim.log.levels.ERROR)
    return false
  end

  if name == state.current_layer then
    local remaining_layers = {}
    for layer_name, _ in pairs(state.layers) do
      if layer_name ~= name then
        table.insert(remaining_layers, layer_name)
      end
    end
    state.current_layer = remaining_layers[1]
  end

  vim.api.nvim_buf_clear_namespace(0, state.namespaces[name], 0, -1)
  state.layers[name] = nil
  state.namespaces[name] = nil

  if state.annotations[name] then
    state.annotations[name] = nil
  end

  vim.notify("Deleted layer: " .. name, vim.log.levels.INFO)
  return true
end

function M.rename_layer(old_name, new_name)
  if not state.layers[old_name] then
    vim.notify("Layer '" .. old_name .. "' does not exist", vim.log.levels.ERROR)
    return false
  end

  if state.layers[new_name] then
    vim.notify("Layer '" .. new_name .. "' already exists", vim.log.levels.ERROR)
    return false
  end

  state.layers[new_name] = state.layers[old_name]
  state.layers[old_name] = nil

  local old_ns = state.namespaces[old_name]
  state.namespaces[new_name] = vim.api.nvim_create_namespace("file_annotator_" .. new_name)
  state.namespaces[old_name] = nil

  if state.annotations[old_name] then
    state.annotations[new_name] = state.annotations[old_name]
    state.annotations[old_name] = nil
  end

  if state.current_layer == old_name then
    state.current_layer = new_name
  end

  vim.api.nvim_buf_clear_namespace(0, old_ns, 0, -1)
  require("file-annotator.highlights").refresh_buffer()

  vim.notify("Renamed layer '" .. old_name .. "' to '" .. new_name .. "'", vim.log.levels.INFO)
  return true
end

function M.set_current_layer(name)
  if not state.layers[name] then
    vim.notify("Layer '" .. name .. "' does not exist", vim.log.levels.ERROR)
    return false
  end

  state.current_layer = name
  vim.notify("Switched to layer: " .. name, vim.log.levels.INFO)
  return true
end

function M.toggle_layer_visibility(name)
  if not state.layers[name] then
    vim.notify("Layer '" .. name .. "' does not exist", vim.log.levels.ERROR)
    return false
  end

  state.layers[name].visible = not state.layers[name].visible
  require("file-annotator.highlights").refresh_buffer()

  local status = state.layers[name].visible and "visible" or "hidden"
  vim.notify("Layer '" .. name .. "' is now " .. status, vim.log.levels.INFO)
  return true
end

function M.list_layers()
  local layers = {}
  for name, layer in pairs(state.layers) do
    table.insert(layers, {
      name = name,
      current = name == state.current_layer,
      visible = layer.visible,
      label_count = vim.tbl_count(layer.labels)
    })
  end

  table.sort(layers, function(a, b) return a.name < b.name end)
  return layers
end

function M.add_label(layer_name, label_name, color)
  layer_name = layer_name or state.current_layer

  if not state.layers[layer_name] then
    vim.notify("Layer '" .. layer_name .. "' does not exist", vim.log.levels.ERROR)
    return false
  end

  if not label_name or label_name == "" then
    vim.notify("Label name cannot be empty", vim.log.levels.ERROR)
    return false
  end

  if state.layers[layer_name].labels[label_name] then
    vim.notify("Label '" .. label_name .. "' already exists in layer '" .. layer_name .. "'", vim.log.levels.WARN)
    return false
  end

  local used_colors = {}
  for _, label in pairs(state.layers[layer_name].labels) do
    used_colors[label.color] = true
  end

  if not color then
    for _, default_color in ipairs(config.default_colors) do
      if not used_colors[default_color] then
        color = default_color
        break
      end
    end

    if not color then
      color = config.default_colors[math.random(#config.default_colors)]
    end
  end

  state.layers[layer_name].labels[label_name] = {
    color = color,
    created_at = os.time()
  }

  require("file-annotator.highlights").create_highlight_group(layer_name, label_name, color)

  vim.notify("Added label '" .. label_name .. "' to layer '" .. layer_name .. "'", vim.log.levels.INFO)
  return true
end

function M.remove_label(layer_name, label_name)
  layer_name = layer_name or state.current_layer

  if not state.layers[layer_name] then
    vim.notify("Layer '" .. layer_name .. "' does not exist", vim.log.levels.ERROR)
    return false
  end

  if not state.layers[layer_name].labels[label_name] then
    vim.notify("Label '" .. label_name .. "' does not exist in layer '" .. layer_name .. "'", vim.log.levels.ERROR)
    return false
  end

  state.layers[layer_name].labels[label_name] = nil

  if state.annotations[layer_name] and state.annotations[layer_name][label_name] then
    state.annotations[layer_name][label_name] = nil
  end

  require("file-annotator.highlights").refresh_buffer()

  vim.notify("Removed label '" .. label_name .. "' from layer '" .. layer_name .. "'", vim.log.levels.INFO)
  return true
end

function M.rename_label(layer_name, old_name, new_name)
  layer_name = layer_name or state.current_layer

  if not state.layers[layer_name] then
    vim.notify("Layer '" .. layer_name .. "' does not exist", vim.log.levels.ERROR)
    return false
  end

  if not state.layers[layer_name].labels[old_name] then
    vim.notify("Label '" .. old_name .. "' does not exist in layer '" .. layer_name .. "'", vim.log.levels.ERROR)
    return false
  end

  if state.layers[layer_name].labels[new_name] then
    vim.notify("Label '" .. new_name .. "' already exists in layer '" .. layer_name .. "'", vim.log.levels.ERROR)
    return false
  end

  state.layers[layer_name].labels[new_name] = state.layers[layer_name].labels[old_name]
  state.layers[layer_name].labels[old_name] = nil

  if state.annotations[layer_name] and state.annotations[layer_name][old_name] then
    state.annotations[layer_name][new_name] = state.annotations[layer_name][old_name]
    state.annotations[layer_name][old_name] = nil
  end

  require("file-annotator.highlights").create_highlight_group(layer_name, new_name, state.layers[layer_name].labels[new_name].color)
  require("file-annotator.highlights").refresh_buffer()

  vim.notify("Renamed label '" .. old_name .. "' to '" .. new_name .. "' in layer '" .. layer_name .. "'", vim.log.levels.INFO)
  return true
end

return M