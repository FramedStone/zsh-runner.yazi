--- @since 26.5.6
local maxOutputBytes = 20 * 1024 * 1024

-- Programs that need a real terminal.
local terminalWords = {}
for _, name in ipairs({
	"lazygit",
	"tig",
	"nvim",
	"vim",
	"vi",
	"nano",
	"emacs",
	"htop",
	"btop",
	"top",
	"less",
	"more",
	"man",
	"fzf",
	"ssh",
	"ranger",
	"mc",
	"tmux",
	"screen",
	"watch",
	"yazi",
}) do
	terminalWords[name] = true
end

-- Get current working directory.
local getCurrentDirectory = ya.sync(function()
	return tostring(cx.active.current.cwd)
end)

-- Open and close the custom modal.
local toggleUI = ya.sync(function(self)
	if self.children then
		Modal:children_remove(self.children)
		self.children = nil
	else
		self.children = Modal:children_add(self, 10)
	end

	ui.render()
end)

-- Transfer command output into Yazi's synchronous UI state.
local setViewerState = ya.sync(function(self, command, exitCode, lines)
	self.command = command
	self.exitCode = exitCode
	self.lines = lines
	self.offset = 0

	ya.dbg(string.format("[zsh-runner] Viewer state updated: %d lines", #self.lines))
end)

-- Update the scroll position.
local updateScroll = ya.sync(function(self, action)
	local maxOffset = math.max(0, #self.lines - self.visibleLines)

	local pageSize = math.max(1, math.floor(self.visibleLines / 2))

	if action == "up" then
		self.offset = self.offset - 1
	elseif action == "down" then
		self.offset = self.offset + 1
	elseif action == "page-up" then
		self.offset = self.offset - pageSize
	elseif action == "page-down" then
		self.offset = self.offset + pageSize
	elseif action == "top" then
		self.offset = 0
	elseif action == "bottom" then
		self.offset = maxOffset
	end

	self.offset = math.max(0, math.min(self.offset, maxOffset))

	ui.render()
end)

-- Split text into individual lines.
local function splitLines(content)
	content = content:gsub("\r\n", "\n")
	content = content:gsub("\r", "\n")

	local lines = {}

	for line in (content .. "\n"):gmatch("(.-)\n") do
		lines[#lines + 1] = line
	end

	if #lines > 1 and lines[#lines] == "" then
		table.remove(lines)
	end

	return lines
end

-- Check if the command needs a terminal.
local function needsTerminal(command)
	for word in command:gmatch("[%w][%w._%-]*") do
		if terminalWords[word] then
			return true
		end
	end

	return false
end

-- Quote text for a POSIX shell.
local function shellQuote(text)
	return "'" .. text:gsub("'", "'\\''") .. "'"
end

local M = {
	offset = 0,
	lines = {},

	-- Keyboard mappings.
	keys = {
		{ on = "q", run = "quit" },
		{ on = "<Esc>", run = "quit" },

		{ on = "j", run = "down" },
		{ on = "k", run = "up" },

		{ on = "<Down>", run = "down" },
		{ on = "<Up>", run = "up" },

		{ on = "<C-d>", run = "page-down" },
		{ on = "<C-u>", run = "page-up" },

		{ on = "<PageDown>", run = "page-down" },
		{ on = "<PageUp>", run = "page-up" },

		{ on = "g", run = "top" },
		{ on = "G", run = "bottom" },
	},

	-- Keyboard synchronization channel.
	permit = table.pack(ya.chan("mpsc", 1)),
}

-- Initialize modal.
function M:new(area)
	self:layout(area)
	return self
end

-- Calculate modal dimensions.
function M:layout(area)
	local chunks = ui.Layout()
		:constraints({
			ui.Constraint.Percentage(10),
			ui.Constraint.Percentage(80),
			ui.Constraint.Percentage(10),
		})
		:split(area)

	local chunks = ui.Layout()
		:direction(ui.Layout.HORIZONTAL)
		:constraints({
			ui.Constraint.Percentage(5),
			ui.Constraint.Percentage(90),
			ui.Constraint.Percentage(5),
		})
		:split(chunks[2])

	self._area = chunks[2]

	local sections = ui.Layout()
		:constraints({
			ui.Constraint.Length(1),
			ui.Constraint.Fill(1),
			ui.Constraint.Length(1),
		})
		:split(self._area:pad(ui.Pad(1, 2, 1, 2)))

	self.titleArea = sections[1]
	self.textArea = sections[2]
	self.footerArea = sections[3]

	self.visibleLines = math.max(1, self.textArea.h)
end

function M:reflow()
	return { self }
end

-- Draw modal.

function M:redraw()
	local lines = self.lines or {}
	local totalLines = #lines

	ya.dbg(
		string.format(
			"[zsh-runner] Redraw: lines=%d, width=%s, height=%s",
			totalLines,
			tostring(self.textArea.w),
			tostring(self.textArea.h)
		)
	)

	local visibleCount = math.max(1, tonumber(self.visibleLines) or 1)

	local offset = math.max(0, tonumber(self.offset) or 0)

	-- Calculate visible range safely.
	local firstLine = 1
	local lastLine = 0

	if totalLines > 0 then
		firstLine = math.min(offset + 1, totalLines)
		lastLine = math.min(totalLines, offset + visibleCount)
	end

	local visibleLines = {}

	-- Render only existing lines.
	if totalLines > 0 then
		for i = firstLine, lastLine do
			local line = tostring(lines[i] or "")

			visibleLines[#visibleLines + 1] = ui.Line(ui.truncate(line, {
				max = math.max(1, tonumber(self.textArea.w) or 1),
			}))
		end
	end

	if #visibleLines == 0 then
		visibleLines[1] = ui.Line("(No output)")
	end

	-- Safely construct header.
	local title = string.format(
		" ZSH OUTPUT | %s | EXIT: %s ",
		tostring(self.command or "Unknown"),
		tostring(self.exitCode or "Unknown")
	)

	-- Safely construct footer.
	local footer = string.format(
		" %d-%d / %d | j/k: Scroll | Ctrl+u/d: Page | g/G: Jump | q: Close ",
		firstLine,
		lastLine,
		totalLines
	)

	return {
		ui.Clear(self._area),

		ui.Border(ui.Edge.ALL):area(self._area):type(ui.Border.ROUNDED):style(ui.Style():fg("cyan")),

		ui.Line(ui.truncate(title, {
			max = math.max(1, self.titleArea.w),
		}))
			:area(self.titleArea)
			:style(ui.Style():fg("cyan"):bold()),

		ui.Text(visibleLines):area(self.textArea):wrap(ui.Wrap.NO),

		ui.Line(ui.truncate(footer, {
			max = math.max(1, self.footerArea.w),
		}))
			:area(self.footerArea)
			:style(ui.Style():fg("darkgray")),
	}
end

-- Main plugin entry point.
function M:entry()
	-- Keep the previously working native input dialog.
	local command, event = ya.input({
		pos = {
			"top-center",
			y = 3,
			w = 70,
		},
		title = "Zsh command:",
		value = "",
	})

	if event ~= 1 or not command or command:match("^%s*$") then
		return
	end

	-- A leading `!` forces terminal mode.
	local forceTerminal = command:match("^%s*!") ~= nil
	command = command:gsub("^%s*!", "")

	if command:match("^%s*$") then
		return
	end

	-- Interactive programs run in Yazi's blocking shell with a real terminal.
	if forceTerminal or needsTerminal(command) then
		ya.emit("shell", { run = "/bin/zsh -ic " .. shellQuote(command), block = true })
		return
	end

	-- Execute using interactive Zsh.
	local output, err = Command("/bin/zsh"):arg({ "-ic", command }):cwd(getCurrentDirectory()):output()

	-- Capture command output.
	local content
	local exitCode

	if output then
		exitCode = output.status and output.status.code or "unknown"

		local sections = {}

		if output.stdout and output.stdout ~= "" then
			sections[#sections + 1] = output.stdout
		end

		if output.stderr and output.stderr ~= "" then
			sections[#sections + 1] = "[STDERR]\n" .. output.stderr
		end

		content = table.concat(sections, "\n")

		if content == "" then
			content = "(Command completed without output.)"
		end
	else
		exitCode = "ERROR"
		content = tostring(err or "Unknown execution error")
	end

	-- Limit memory usage.
	if #content > maxOutputBytes then
		content = content:sub(1, maxOutputBytes) .. "\n\n[Output truncated at 20 MiB]"
	end

	-- Transfer output into synchronous UI state.
	setViewerState(command:gsub("%s+", " "), exitCode, splitLines(content))

	-- Open modal.
	toggleUI()

	-- Create communication channel.
	local tx, rx = ya.chan("mpsc")

	-- Read keyboard input.
	local function producer()
		self.permit[1]:send(true)

		while true do
			if ya.iter then
				self.permit[2]()
			else
				self.permit[2]:recv()
			end

			local index = ya.which({
				cands = self.keys,
				silent = true,
			})

			self.permit[1]:send(true)

			-- Cancelled input closes the viewer safely.
			if not index then
				tx:send("quit")
				toggleUI()
				return
			end

			local action = self.keys[index].run

			tx:send(action)

			if action == "quit" then
				toggleUI()
				return
			end
		end
	end

	-- Process navigation events.
	local function consumer()
		while true do
			local action

			if ya.iter then
				action = rx()
			else
				action = rx:recv()
			end

			if not action or action == "quit" then
				return
			end

			updateScroll(action)
		end
	end

	-- Run both tasks using Yazi's plugin lifecycle.
	ya.join(producer, consumer)
end

return M
