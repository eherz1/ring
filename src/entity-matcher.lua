local EntityMatcher = {}

EntityMatcher.__index = EntityMatcher

function EntityMatcher:new()
  return setmetatable({}, self)
end

function EntityMatcher:matches(entityId)
  return false
end
