local EntitySystem = {}

EntitySystem.__index = System

function EntitySystem:new(matcher)
  return setmetatable({
    matcher = matcher,
    entities = {},
  }, self)
end

function EntitySystem:initialize()
  for _, entityId in pairs(self.world.entities) do
    self.entityId = self.matcher:matches(entityId)
  end

  self.world:addListener("onComponentAdded", self)
  self.world:addListener("onComponentRemoved", self)
  self.world:addListener("onEntityCreated", self)
  self.world:addListener("onEntityDestroyed", self)
end

function EntitySystem:destroy()
  self.world:removeListener("onComponentAdded", self)
  self.world:removeListener("onComponentRemoved", self)
  self.world:removeListener("onEntityAdded", self)
  self.world:removeListener("onEntityRemoved", self)
end

function EntitySystem:onComponentAdded(entityId, componentName)
  self.entities[entityId] = self.matcher:matches(entityId)
end

function EntitySystem:onComponentRemoved(entityId, componentName)
  self.entities[entityId] = self.matcher:matches(entityId)
end

function EntitySystem:onEntityAdded(entityId)
  self.entities[entityId] = self.matcher:matches(entityId)
end

function EntitySystem:onEntityDestroyed(entityId)
  self.entities[entityId] = nil
end

function EntitySystem:updateEntity(entityId, dt)
end

function EntitySystem:update(dt)
  for entityId, _ in pairs(self.entities) do
    self:updateEntity(entityId, dt)
  end
end

function EntitySystem:processEntity(entityId)
end

function EntitySystem:process()
  for entityId, _ in pairs(self.entities) do
    self:processEntity(entityId)
  end
end

return EntitySystem
