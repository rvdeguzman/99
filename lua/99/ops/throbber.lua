local time = require("99.time")
local throb_icons = {
  { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
  { "◐", "◓", "◑", "◒" },
  { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
  { "◰", "◳", "◲", "◱" },
  { "◜", "◠", "◝", "◞", "◡", "◟" },
}

--- @alias _99.Throbber.ThrobFN fun(perc: number): string
--- @alias _99.Throbber.EaseFN fun(perc: number): number

--- @param ease_fn _99.Throbber.EaseFN
--- @return _99.Throbber.ThrobFN
local function create_throbber(ease_fn)
  ease_fn = ease_fn or function(p)
    return p
  end
  local icon_set = throb_icons[math.random(#throb_icons)]
  return function(percent)
    local eased = ease_fn(percent)
    local index = math.floor(eased * #icon_set) + 1
    return icon_set[math.min(index, #icon_set)]
  end
end

local function ease_in_ease_out_cubic(percent)
  if percent < 0.5 then
    return 4 * percent * percent * percent
  else
    local f = (2 * percent) - 2
    return 1 - (f * f * f / 2)
  end
end

local throb_time = 1000
local cooldown_time = 500

--- @class _99.Throbber
--- @field start_time number
--- @field section_time number
--- @field state "init" | "throbbing" | "cooldown" | "stopped"
--- @field throb_fn _99.Throbber.ThrobFN
--- @field cb fun(str: string): nil
local Throbber = {}
Throbber.__index = Throbber

--- @param cb fun(str: string): nil
--- @return _99.Throbber
function Throbber.new(cb)
  return setmetatable({
    state = "init",
    start_time = 0,
    section_time = 0,
    cb = cb,
    throb_fn = create_throbber(ease_in_ease_out_cubic),
  }, Throbber)
end

function Throbber:_run()
  if self.state ~= "throbbing" and self.state ~= "cooldown" then
    return
  end

  local elapsed = time.now() - self.start_time
  local percent = math.min(1, elapsed / self.section_time)
  local icon = self.throb_fn(self.state == "throbbing" and percent or 1)

  if percent == 1 then
    self.state = self.state == "cooldown" and "throbbing" or "cooldown"
    self.start_time = time.now()
    self.section_time = self.state == "cooldown" and cooldown_time or throb_time
  end

  self.cb(icon)
  vim.defer_fn(function()
    self:_run()
  end, 75)
end

function Throbber:start()
  self.start_time = time.now()
  self.section_time = throb_time
  self.state = "throbbing"
  self:_run()
end

function Throbber:stop()
  self.state = "stopped"
end

Throbber._icons = throb_icons

return Throbber
