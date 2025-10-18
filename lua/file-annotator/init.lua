local M = {}

M.config = {
  default_colors = {
    "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7",
    "#DDA0DD", "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E9"
  },
  export_dir = vim.fn.stdpath("data") .. "/file-annotator/exports"
}

M.state = {
  labels = {},  -- Global labels: label_name -> {color, created_at}
  annotations = {},  -- Annotations: label_name -> line_num -> annotation_id -> {bufnr, filename, timestamp, col_start, col_end}
  namespace = nil  -- Single namespace for all annotations
}

local function ensure_export_dir()
  vim.fn.mkdir(M.config.export_dir, "p")
end

function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.config, opts)
  ensure_export_dir()

  -- Initialize single namespace for all annotations
  M.state.namespace = vim.api.nvim_create_namespace("file_annotator")

  require("file-annotator.commands").setup()
  require("file-annotator.highlights").setup()
end

return M
