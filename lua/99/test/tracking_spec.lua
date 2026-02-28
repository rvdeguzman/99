-- luacheck: globals describe it assert
local Prompt = require("99.prompt")
local Tracking = require("99.state.tracking")
local eq = assert.are.same

local function data_for(operation)
  if operation == "tutorial" then
    return {
      type = "tutorial",
      xid = 1,
      buffer = 0,
      window = 0,
      tutorial = {},
    }
  end

  if operation == "visual" then
    return {
      type = "visual",
      buffer = 0,
      file_type = "lua",
      range = {
        start_row = 1,
        start_col = 1,
        end_row = 1,
        end_col = 1,
      },
    }
  end

  if operation == "vibe" then
    return {
      type = "vibe",
      response = "",
      qfix_items = {},
    }
  end

  return {
    type = "search",
    response = "",
    qfix_items = {},
  }
end

local function track_request(state, operation, started_at, status)
  local prompt = Prompt.deserialize(state, {
    user_prompt = string.format("%s-%d", operation, started_at),
    data = data_for(operation),
  })
  prompt.started_at = started_at
  prompt.state = status
  state.tracking:track(prompt)
end

describe("tracking", function()
  it("serialize respects Tracking.serialized_counts", function()
    local state = {}
    state.tracking = Tracking.new(state, nil)

    local expected_total = 0
    local started_at = 0
    for operation, count in pairs(Tracking.serialize_counts) do
      expected_total = expected_total + count
      for _ = 1, count + 2 do
        started_at = started_at + 1
        track_request(state, operation, started_at, "success")
      end

      started_at = started_at + 1
      track_request(state, operation, started_at, "failed")
    end

    local serialized = state.tracking:serialize()
    local actual_counts = {}
    for _, request in ipairs(serialized.requests) do
      local operation = request.data.type
      actual_counts[operation] = (actual_counts[operation] or 0) + 1
    end

    eq(expected_total, #serialized.requests)
    for operation, count in pairs(Tracking.serialize_counts) do
      eq(count, actual_counts[operation] or 0)
    end
  end)
end)
