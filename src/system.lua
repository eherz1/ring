local System = {}

System.__index = System

function System:new()
  return setmetatable({}, self)
end

function System:initialize()
end

function System:destroy()
end

function System:update(dt)
end

function System:process()
end

return System
