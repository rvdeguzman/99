local Prompt = require("99.prompt")

--- @class _99.State.Tracking.Serialized
--- @field requests _99.Prompt.Serialized[]

--- @class _99.State.Tracking
--- @field history _99.Prompt[]
--- @field id_to_request table<number, _99.Prompt>
local Tracking = {}

--- @param _99 _99.State
--- @param previous_state _99.State.Tracking.Serialized | nil
--- @return _99.State.Tracking
function Tracking.new(_99, previous_state)
  local tracking = setmetatable({}, Tracking) --[[ @as _99.State.Tracking]]

  tracking.history = {}
  tracking.id_to_request = {}

  if not previous_state then
    return tracking
  end

  for _, d in ipairs(previous_state.requests or {}) do
    local prompt = Prompt.deserialize(_99, d)
    table.insert(tracking.history, prompt)
    tracking.id_to_request[prompt.xid] = prompt
  end

  return tracking
end

--- @param context _99.Prompt
function Tracking:track(context)
  assert(context:valid(), "context is not valid")
  table.insert(self.history, context)
  self.id_to_request[context.xid] = context
end

--- @return number
function Tracking:completed()
  local count = 0
  for _, entry in ipairs(self.history) do
    if entry.state ~= "requesting" then
      count = count + 1
    end
  end
  return count
end

function Tracking:clear_history()
  local keep = {}
  for _, entry in ipairs(self.history) do
    if entry.state == "requesting" then
      table.insert(keep, entry)
    else
      self.id_to_request[entry.xid] = nil
    end
  end
  self.history = keep
end

function Tracking:active_request_count()
  local count = 0
  for _, r in pairs(self.history) do
    if r.state == "requesting" then
      count = count + 1
    end
  end
  return count
end

--- @param type "search" | "visual" | "tutorial"
--- @return _99.Prompt[]
function Tracking:request_by_type(type)
  local out = {} --[[ @as _99.Prompt[] ]]
  for _, r in ipairs(self.history) do
    if r.operation == type then
      table.insert(out, r)
    end
  end
  return out
end

--- @return _99.State.Tracking.Serialized
function Tracking:serialize()
  local requests = {}
  for _, r in ipairs(self.history) do
    table.insert(requests, r:serialize())
  end
  return {
    requests = requests,
  }
end

return Tracking
