-- Drupal's PHP files: .module, .inc, .install, .theme, .profile, .engine are php inside a Drupal
-- tree (a parent dir has core/lib/Drupal.php). Elsewhere these extensions mean other things
-- (.inc in Pascal or BitBake, .install in Arch packages), so outside Drupal nothing changes.

---@param path string
---@return string|nil
local function php_in_drupal(path)
	for dir in vim.fs.parents(path) do
		if vim.uv.fs_stat(dir .. '/core/lib/Drupal.php') then
			return 'php'
		end
	end
	return nil
end

---@type vim.filetype.add.filetypes
return {
	extension = {
		module = php_in_drupal,
		inc = php_in_drupal,
		install = php_in_drupal,
		theme = php_in_drupal,
		profile = php_in_drupal,
		engine = php_in_drupal,
	},
}
