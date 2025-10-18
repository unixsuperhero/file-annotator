local M = {}
local annotations = require("file-annotator.annotations")
local export = require("file-annotator.export")

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
  -- Label management commands
  vim.api.nvim_create_user_command("FAAddLabel", function(opts)
    local args = vim.split(opts.args, " ", { plain = true })
    if #args < 1 then
      vim.notify("Usage: FAAddLabel <label_name> [color]", vim.log.levels.ERROR)
      return
    end
    local label_name = args[1]
    local color = args[2]
    annotations.add_label(label_name, color)
  end, {
    nargs = "+",
    desc = "Add a new label"
  })

  vim.api.nvim_create_user_command("FARemoveLabel", function(opts)
    annotations.remove_label(opts.args)
  end, {
    nargs = 1,
    complete = M.complete_labels,
    desc = "Remove a label"
  })

  vim.api.nvim_create_user_command("FARenameLabel", function(opts)
    local args = vim.split(opts.args, " ", { plain = true })
    if #args ~= 2 then
      vim.notify("Usage: FARenameLabel <old_name> <new_name>", vim.log.levels.ERROR)
      return
    end
    annotations.rename_label(args[1], args[2])
  end, {
    nargs = "+",
    complete = M.complete_labels,
    desc = "Rename a label"
  })

  vim.api.nvim_create_user_command("FAListLabels", function()
    M.show_labels_info()
  end, {
    desc = "List all labels"
  })

  -- Annotation commands
  vim.api.nvim_create_user_command("FAAnnotate", function(opts)
    local label_name = opts.args

    if label_name == "" then
      vim.notify("Usage: FAAnnotate <label_name>", vim.log.levels.ERROR)
      return
    end

    -- Check if this is a range command
    if opts.range == 2 then
      -- Range was specified (e.g., :5,10FAAnnotate label)
      annotations.annotate_range(opts.line1, opts.line2, label_name)
    elseif opts.range == 1 then
      -- Single line range (e.g., :5FAAnnotate label)
      annotations.annotate_line(opts.line1, label_name)
    else
      -- No range, use current line
      local line_num = vim.fn.line(".")
      annotations.annotate_line(line_num, label_name)
    end
  end, {
    nargs = 1,
    range = true,
    complete = M.complete_labels,
    desc = "Annotate current line or range with label"
  })

  vim.api.nvim_create_user_command("FARemoveAnnotation", function(opts)
    local line_num = vim.fn.line(".")
    local label_name = opts.args
    if label_name == "" then
      vim.notify("Usage: FARemoveAnnotation <label_name>", vim.log.levels.ERROR)
      return
    end
    annotations.remove_annotation(line_num, label_name)
  end, {
    nargs = 1,
    complete = M.complete_labels,
    desc = "Remove annotation from current line"
  })

  vim.api.nvim_create_user_command("FAToggleAnnotation", function(opts)
    local line_num = vim.fn.line(".")
    local label_name = opts.args
    if label_name == "" then
      vim.notify("Usage: FAToggleAnnotation <label_name>", vim.log.levels.ERROR)
      return
    end
    annotations.toggle_annotation(line_num, label_name)
  end, {
    nargs = 1,
    complete = M.complete_labels,
    desc = "Toggle annotation on current line"
  })

  vim.api.nvim_create_user_command("FAClearAnnotations", function(opts)
    local label_name = opts.args ~= "" and opts.args or nil
    annotations.clear_all_annotations(label_name)
  end, {
    nargs = "?",
    complete = M.complete_labels,
    desc = "Clear all annotations (optionally for specific label)"
  })

  -- Visual mode annotation
  vim.api.nvim_create_user_command("FAAnnotateSelection", function(opts)
    local label_name = opts.args

    if label_name == "" then
      vim.notify("Usage: FAAnnotateSelection <label_name>", vim.log.levels.ERROR)
      return
    end

    annotations.annotate_selection(label_name)
  end, {
    nargs = 1,
    complete = M.complete_labels,
    range = true,
    desc = "Annotate selected lines with label"
  })

  -- Export commands
  vim.api.nvim_create_user_command("FAExportHTML", function(opts)
    local filename = opts.args ~= "" and opts.args or nil
    export.export_to_html(filename)
  end, {
    nargs = "?",
    desc = "Export annotations to HTML"
  })

  vim.api.nvim_create_user_command("FAShowStats", function()
    M.show_annotation_stats()
  end, {
    desc = "Show annotation statistics"
  })

  -- Import/Export commands
  vim.api.nvim_create_user_command("FAExportAnnotations", function(opts)
    local filename = opts.args ~= "" and opts.args or nil
    export.export_annotations_to_json(filename)
  end, {
    nargs = "?",
    desc = "Export annotations to JSON file"
  })

  vim.api.nvim_create_user_command("FAImportAnnotations", function(opts)
    if opts.args == "" then
      vim.notify("Usage: FAImportAnnotations <filename>", vim.log.levels.ERROR)
      return
    end
    export.import_annotations_from_json(opts.args)
  end, {
    nargs = 1,
    complete = "file",
    desc = "Import annotations from JSON file"
  })

  -- Quick setup command
  vim.api.nvim_create_user_command("FAQuickSetup", function()
    M.quick_setup()
  end, {
    desc = "Quick setup with default labels"
  })
end

function M.complete_labels(arg_lead, cmd_line, cursor_pos)
  local state = require("file-annotator").state
  local label_names = {}

  for name, _ in pairs(state.labels) do
    if vim.startswith(name, arg_lead) then
      table.insert(label_names, name)
    end
  end

  return label_names
end

function M.show_labels_info()
  local label_list = annotations.list_labels()

  if #label_list == 0 then
    vim.notify("No labels created yet", vim.log.levels.INFO)
    return
  end

  local lines = {"File Annotator Labels:", ""}

  for _, label in ipairs(label_list) do
    table.insert(lines, string.format("• %s (%s)", label.name, label.color))
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

function M.show_annotation_stats()
  local stats = export.export_label_stats()

  local lines = {"Annotation Statistics:", ""}
  lines[#lines + 1] = string.format("Total annotations: %d", stats.total_annotations)
  lines[#lines + 1] = string.format("Total labels: %d", stats.label_count)
  lines[#lines + 1] = ""

  for label_name, count in pairs(stats.labels) do
    lines[#lines + 1] = string.format("• %s: %d lines", label_name, count)
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

function M.quick_setup()
  -- Add default labels
  annotations.add_label("good", "#4ECDC4")
  annotations.add_label("needs_work", "#FF6B6B")
  annotations.add_label("unclear", "#FFEAA7")
  annotations.add_label("bug", "#FF4757")
  annotations.add_label("security", "#FF3838")
  annotations.add_label("performance", "#FF9F43")
  annotations.add_label("important", "#5F27CD")
  annotations.add_label("todo", "#00D2D3")
  annotations.add_label("question", "#FF9FF3")

  vim.notify("Quick setup complete! Created 9 default labels.", vim.log.levels.INFO)
end

-- Key mapping helpers
function M.setup_keymaps()
  -- Example keymaps - users can customize these
  local opts = { noremap = true, silent = true }

  -- Quick annotation with number keys
  for i = 1, 9 do
    vim.keymap.set("n", "<leader>a" .. i, function()
      local state = require("file-annotator").state
      local labels = {}
      for name, _ in pairs(state.labels) do
        table.insert(labels, name)
      end
      table.sort(labels)

      if labels[i] then
        local line_num = vim.fn.line(".")
        annotations.toggle_annotation(line_num, labels[i])
      end
    end, opts)
  end

  -- List labels
  vim.keymap.set("n", "<leader>al", function()
    M.show_labels_info()
  end, opts)

  -- Export
  vim.keymap.set("n", "<leader>ae", function()
    export.export_to_html()
  end, opts)
end

return M
