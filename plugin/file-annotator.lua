-- File Annotator Plugin Entry Point
-- This file ensures the plugin is loaded when Neovim starts

if vim.g.loaded_file_annotator then
  return
end
vim.g.loaded_file_annotator = 1

-- Initialize the plugin
require("file-annotator").setup()