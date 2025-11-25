local Logger = require("99.logger.logger")
local Level = require("99.logger.level")
local editor = require("99.editor")
local geo = require("99.geo")
local Point = geo.Point

local marks_to_use = "yuiophjkl"

--- @class LoggerOptions
--- @field level number?
--- @field path string?

--- @class _99Options
--- @field logger LoggerOptions?
--- @field model string?

--- @alias _99ChangeRequestState "ready" | "calling-model" | "parsing-result" | "updating-file"

--- @class _99ChangeRequest
--- @field query string
--- @field tmp_name string
--- @field state _99ChangeRequestState
--- @field buffer number
--- @field model string
--- @field id string
--- @field mark string
--- @field range Range

--- unanswered question -- will i need to queue messages one at a time or
--- just send them all...  So to prepare ill be sending around this state object
--- @class _99State
--- @field model string
--- @field mark_index number

local _99_settings = {
	output_file = "you must NEVER alter the file given.  You must provide the desired change to TEMP_FILE. Do NOT inspec the TEMP_FILE.  It is for you to write into, never read.  TEMP_FILE previous contents do not matter.",
	fill_in_function = "fill in the function.  dont change the function signature. do not edit anything outside of this function.  prioritize using internal functions for work that has already been done.  any NOTE's left in the function should be removed but instructions followed",
}

--- @type _99State
local _99_state = {
	model = "anthropic/claude-sonnet-4-5",
    mark_index = 0,
}

--- no, i am not going to use a uuid, in case of collision, call the police
--- @return string
local function get_id()
	return tostring(math.floor(math.random() * 100000000))
end

--- TODO: some people change their current working directory as they open new
--- directories.  if this is still the case in neovim land, then we will need
--- to make the _99_state have the project directory.
--- @return string
local function random_file()
	return string.format("%s/tmp/99-%d", vim.uv.cwd(), math.floor(math.random() * 10000))
end

--- @param tmp_file string
local function system_rules(tmp_file)
	return string.format(
		"<MustObey>\n%s\n%s\n</MustObey><TEMP_FILE>%s</TEMP_FILE>",
		_99_settings.output_file,
		_99_settings.fill_in_function,
		tmp_file
	)
end

--- @param buffer number
---@param range Range
---@return string
local function get_file_location(buffer, range)
	local full_path = vim.fn.expand("%:p")
	return string.format("<Location><File>%s</File><Function>%s</Function></Location>", full_path, range:to_string())
end

--- @param range Range
local function get_range_text(range)
	return string.format("<FunctionText>%s</FunctionText>", range:to_text())
end

--- @class _99
local _99 = {}

--- @param change_request _99ChangeRequest
function _99.mark_function(change_request)
    local range = change_request.range
    local start_row, start_col = range.start:to_vim()

    local mark = marks_to_use:sub(_99_state.mark_index + 1, _99_state.mark_index + 1)
    vim.api.nvim_buf_set_mark(change_request.buffer, mark, start_row + 1, start_col, {})

    _99_state.mark_index = (_99_state.mark_index + 1) % #marks_to_use

    change_request.mark = mark
end

--- @param change_request _99ChangeRequest
function _99.make_query(change_request)
	Logger:debug("99#make_query", "id", change_request.id, "query", change_request.query)
	vim.system({ "opencode", "run", "-m", "anthropic/claude-sonnet-4-5", change_request.query }, {
		text = true,
		stdout = vim.schedule_wrap(function(err, data)
			Logger:debug("STDOUT#data", "id", change_request.id, "data", data)
			Logger:debug("STDOUT#error", "id", change_request.id, "err", err)
		end),
		stderr = vim.schedule_wrap(function(err, data)
			Logger:debug("STDERR#data", "id", change_request.id, "data", data)
			Logger:debug("STDERR#error", "id", change_request.id, "err", err)
		end),
	}, function(obj)
		if obj.code ~= 0 then
			Logger:fatal("opencode make_query failed", "change_request", change_request, "obj from results", obj)
			return
		end
		local ok, res = _99.retrieve_results(change_request)
		if ok then
			_99.update_file_with_changes(change_request, res)
		end
	end)
end

--- @param change_request _99ChangeRequest
--- @return boolean, string
function _99.retrieve_results(change_request)
	local success, result = pcall(function()
		return vim.fn.readfile(change_request.tmp_name)
	end)

	if not success then
		Logger:error("retrieve_results: failed to read file", "tmp_name", change_request.tmp_name, "error", result)
		return false, ""
	end

	return true, table.concat(result, "\n")
end

--- @param change_request _99ChangeRequest
--- @param res string
function _99.update_file_with_changes(change_request, res)
    --- NOTE use treesitter to get the range of the function
    --- NOTE remove the previous contents of function
    --- NOTE replace with results stored in res
end

function _99.fill_in_function()
	local ts = editor.treesitter
	local cursor = Point:from_cursor()
	local scopes = ts.function_scopes(cursor)
	local buffer = vim.api.nvim_get_current_buf()

	if scopes == nil or #scopes.range == 0 then
		Logger:warn("fill_in_function: unable to find any containing function")
		error("you cannot call fill_in_function not in a function")
	end

	local tmp_file = random_file()
	local range = scopes.range[#scopes.range]

	--- @type _99ChangeRequest
	local change_request = {
        range = range,
		buffer = buffer,
		tmp_name = tmp_file,
		state = "ready",
		query = table.concat({
			system_rules(tmp_file),
			get_file_location(buffer, range),
			get_range_text(range),
		}),
		model = _99_state.model,
		id = get_id(),
        mark = "",
	}
	_99.make_query(change_request)
end

--- @param opts _99Options?
function _99.setup(opts)
	opts = opts or {}
	local logger = opts.logger
	if logger then
		if logger.level then
			Logger:set_level(logger.level)
		end
		if logger.path then
			Logger:file_sink(logger.path)
		end
	end
	if opts.model then
		_99_state.model = opts.model
	end
end

--- @param model string
function _99.set_model(model)
	_99_state.model = model
end

Logger:set_level(Level.DEBUG)
Logger:file_sink("/tmp/99.debug")

_99.fill_in_function()

return _99
