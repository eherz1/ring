local World = {}

function World:new(args)
  local inst = {}
  inst.components = {}
  inst.entities = {}
  inst.systems = {}
  inst.listeners = {
    componentAdded = {},
    componentRemoved = {},
    entityCreated = {},
    entityDestroyed = {}
  }
  return setmetatable({}, self)
end

local broadcastComponentAdded = function(world, entityId, componentName)
  for _, listener in ipairs(world.listeners.componentAdded) do
    listener:onComponentAdded(entityId, componentName)
  end
end

local broadcastComponentRemoved = function(world, entityId, componentName)
  for _, listener in ipairs(world.listeners.componentAdded) do
    listener:onComponentRemoved(entityId, componentName)
  end
end

function World:addComponent(entityId, componentName, defaults)
  self.components[componentName][entityId] = defaults
  broadcastComponentAdded(entityId, componentName)
end

function World:removeComponent(entityId, componentName)
  self.components[componentName][entityId] = nil
  broadcastComponentRemoved(entityId, componentName)
end

function World:getComponent(entityId, componentName)
  return self.components[componentName][entityId]
end

function World:hasComponent(entityId, componentName)
  return self.components[componentName][entityId] ~= nil
end

local entityIdCounter = 0

local nextEntityId = function()
  entityIdCounter = entityIdCounter + 1
  return entityIdCounter
end

local broadcastEntityCreated = function(world, entityId)
  for _, listener in ipairs(world.listeners.entityCreated) do
    listener:onEntityCreated(entityId)
  end
end

local broadcastEntityDestroyed = function(world, entityId)
  for _, listener in ipairs(world.listeners.entityDestroyed) do
    listener:onEntityDestroyed(entityId)
  end
end

function World:createEntity(components)
  local entityId = nextEntityId()
  self.entities[entityId] = true
  for componentName, defaults in pairs(components) do
    self.components[componentName][entityId] = defaults
  end
  broadcastEntityAdded(self, entityId)
end

function World:destroyEntity(entityId)
  self.entities[entityId] = nil
  broadcastEntityRemoved(entityId)
end

function World:addSystem(system)
  system.world = self
  system:initialize()
  table.insert(self.systems, system)
  return id
end

function World:removeSystem(system)
  for i, s in ipairs(self.systems) do
    if s == system then
      table.remove(self.systems, i)
      system:destroy()
      return
    end
  end
end

function World:addListener(eventName, listener)
  table.insert(self.listeners[eventName], listener)
end

function World:removeListener(eventName, listener)
  for i, l in ipairs(self.listeners[eventName]) do
    if l == listener then
      table.remove(i)
      return
    end
  end
end

function World:update(dt)
  for _, system in ipairs(self.systems) do
    system:update(dt)
  end
end

function World:process()
  for _, system in ipairs(self.systems) do
    system:process()
  end
end

return World
