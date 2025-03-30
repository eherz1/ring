local ring = {}

-- Create a new System. System is a basic system that calls update and process
-- methods in sequence every tick.
-- @param system.initialize Optional function of form () => void which will be called when the system is added to a world.
-- @param system.destroy Optional function of form () => void which will be called when the system is removed from a world.
-- @param system.update Required function of form (delta) => void to compute updates before frame processing.
-- @param system.process Required function of form () => void to do frame processing.
ring.newSystem = function(system)
  local inst = {}

  for k, v in pairs(system) do
    inst[k] = v
  end

  inst.initialize = system.initialize or function(self) end

  inst.destroy = system.destroy or function(self) end

  inst.update = system.update or function(self, dt)
    error("System.update must be implemented")
  end

  inst.process = system.process or function(self)
    error("System.process must be implemented")
  end

  return inst
end

-- Create a new EventSystem. EventSystem is a system that is primarily
-- interested in responding to events that occur on the world to which the
-- system belongs. It may implement per-tick update / process operations, but
-- those methods provide a default no-op implementation and are considered
-- optional.
-- @param system.initialize Optional function of form () => void which will be called when the system is initialized.
-- @param system.destroy Optional function of form () => void which will be called when the system is destroyed.
-- @param system.onEntityCreated Optional function of form (entityId) => void.
-- @param system.onEntityDestroyed Optional function of form (entityId) => void.
-- @param system.onComponentAdded Optional function of form (entityId, componentName) => void.
-- @param system.onComponentRemoved Optional function of form (entityId, componentName) => void.
ring.newEventSystem = function(system)
  local inst = {}

  for k, v in pairs(system) do
    inst[k] = v
  end

  inst.initialize = function(self)
    if system.onEntityCreated then
      self.world:addListener("entityCreated", self)
    end

    if system.onEntityDestroyed then
      self.world:addListener("entityDestroyed", self)
    end

    if system.onComponentAdded then
      self.world:addListener("componentAdded", self)
    end

    if system.onComponentRemoved then
      self.world:addListener("componentRemoved", self)
    end

    if system.initialize then
      system.initialize(self)
    end
  end

  inst.destroy = function(self)
    if system.onEntityCreated then
      self.world:removeListener(self)
    end

    if system.onEntityDestroyed then
      self.world:addListener(self)
    end

    if system.onComponentAdded then
      self.world:addListener(self)
    end

    if system.onComponentRemoved then
      self.world:addListener(self)
    end

    if system.destroy then
      system.destroy()
    end
  end

  inst.update = system.update or function(self, dt) end

  inst.process = system.process or function(self) end

  return inst
end

-- Create a new EntitySystem. EntitySystem performs iterative processing on a set of entity ids.
-- @param system.initialize Optional function of form () => void which will be called when the system is initialized.
-- @param system.destroy Optional function of form () => void which will be called when the system is destroyed.
-- @param system.match Function of form (entityId) => boolean which returns true if this system processes the entity.
-- @param system.update Optional function of form (delta) => void to compute pre process updates.
-- @param system.process Optional function of form () => void to do frame processing.
-- @param system.updateEntity Required function of form (entityId, delta) => void to compute pre process updates on entityId.
-- @param system.processEntity Required function of form (entityId) => void to do frame processing on entityId.
ring.newEntitySystem = function(system)
  local inst = {}

  for k, v in pairs(system) do
    inst[k] = v
  end

  inst.entities = {}

  inst.initialize = function(self)
    for _, entityId in pairs(self.world.entities) do
      self.entities[entityId] = self:match(entityId)
    end
  
    self.world:addListener("componentAdded", self)
    self.world:addListener("componentRemoved", self)
    self.world:addListener("entityCreated", self)
    self.world:addListener("entityDestroyed", self)

    if system.initialize then
      system.initialize(self)
    end
  end

  inst.destroy = function(self)
    self.world:removeListener("componentAdded", self)
    self.world:removeListener("componentRemoved", self)
    self.world:removeListener("entityAdded", self)
    self.world:removeListener("entityRemoved", self)

    if system.destroy then
      system.destroy(self)
    end
  end

  inst.match = system.match or function(self, entityId)
    error("EntitySystem.match must be implemented")
  end

  inst.onComponentAdded = function(self, entityId, componentName)
    self.entities[entityId] = self:match(entityId)
  end
  
  inst.onComponentRemoved = function(self, entityId, componentName)
    self.entities[entityId] = self:match(entityId)
  end
  
  inst.onEntityCreated = function(self, entityId)
    if self:match(entityId) then
      self.entities[entityId] = true
    end
  end
  
  inst.onEntityDestroyed = function(self, entityId)
    self.entities[entityId] = nil
  end

  inst.updateEntity = system.updateEntity or function(entityId, dt)
    error("EntitySystem.updateEntity must be implemented")
  end

  inst.update = function(self, dt)
    for entityId, _ in pairs(self.entities) do
      self:updateEntity(entityId, dt)
    end

    if system.update then
      system.update(self, dt)
    end
  end

  inst.processEntity = system.processEntity or function(self, entityId)
    error("EntitySystem.processEntity must be implemented")
  end

  inst.process = function(self)
    for entityId, _ in pairs(self.entities) do
      self:processEntity(entityId)
    end

    if system.process then
      system.process(self)
    end
  end

  return inst
end

-- Create a new world. World represents a context in which a set of entities
-- with various compositional components are acted upon by a ordered set of
-- of systems.
ring.newWorld = function()
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

  -- Add a component to an entity. The form of a component is unstructured,
  -- but if defaults are provided, the component will be initialized with
  -- those values. Otherwise, the component will be initialized to boolean
  -- 'true'.
  -- @param entityId The entityId of the entity to add the component to.
  -- @param componentName The name of the component.
  -- @param defaults Optional table of values to initialize the component with.
  inst.addComponent = function(self, entityId, componentName, defaults)
    self.components[componentName][entityId] = defaults or true
    broadcastComponentAdded(entityId, componentName)
  end

  -- Remove a component from an entity.
  -- @param entityId The entityId of the entity to remove the component from.
  -- @param componentName The name of the component to remove.
  inst.removeComponent = function(self, entityId, componentName)
    self.components[componentName][entityId] = nil
    broadcastComponentRemoved(entityId, componentName)
  end

  -- Get a component from an entity.
  -- @param entityId The entityId of the entity to get the component of.
  -- @param componentName The name of the component to get.
  inst.getComponent = function(self, entityId, componentName)
    local component = self.components[componentName]
    if component then
      return component[entityId]
    end
    return nil
  end

  -- Check whether an entity has a component.
  -- @param entityId The entityId of the entity to check the component of.
  -- @param componentName The name of the component to check.
  -- @return Boolean truth as to whether the entity has the component.
  inst.hasComponent = function(self, entityId, componentName)
    local component = self.components[componentName]
    return component ~= nil and component[entityId] ~= nil
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

  -- Create a new entity in this world. Broadcasts the event "entityCreated" on creation.
  -- @param components An optional table of format { componentName1 = defaults1, componentName2 = defaults2... } where defaults is an optional table of properties to initialize the component with.
  inst.createEntity = function(self, components)
    local entityId = nextEntityId()
    self.entities[entityId] = true
    if components ~= nil then
      for componentName, defaults in pairs(components) do
        local component = self.components[componentName]
        if component == nil then
          component = {}
          self.components[componentName] = component
        end
        component[entityId] = defaults
      end
    end
    broadcastEntityCreated(self, entityId)
  end

  -- Destroy an entity in this world. Broadcasts the event "entityDestroyed" on destruction.
  -- @param entityId The entityId of the entity to destroy.
  inst.destroyEntity = function(self, entityId)
    self.entities[entityId] = nil
    broadcastEntityDestroyed(entityId)
  end

  -- Add a system to this world.
  -- @param system The system to add to this world. Create a system using ring.new*System() functions.
  inst.addSystem = function(self, system)
    system.world = self
    system:initialize()
    table.insert(self.systems, system)
  end

  -- Remove a system from this world. Removes by reference check, so you must
  -- have a reference to the system if you want to remove it.
  -- @param system The system to remove from this world.
  inst.removeSystem = function(self, system)
    for i, s in ipairs(self.systems) do
      if s == system then
        table.remove(self.systems, i)
        system:destroy()
        return
      end
    end
  end

  -- inst.getSystem = function(self, system)
  --   for _, s in ipairs(self.systems) do
  --     if s == system then
  --       return s
  --     end
  --   end
  --   return nil
  -- end

  -- Add a listener on this world. A listener may listen to the following events:
  -- - componentAdded, with callback of form onComponentAdded(entityId, componentName) => void, which is called when a component is added to an entity.
  -- - componentRemoved, with callback of form (entityId, componentName) => void, which is called when a component is removed from an entity.
  -- - entityAdded, with callback of form (entityId) => void, which is called when an entity is added to this world.
  -- - entityRemoved, with callback of form (entityId) => void, which is called when an entity is removed from this world.
  -- @param eventName The name of the event to listen to.
  -- @param listener A reference to a table that defines a callback function of the respective event.
  inst.addListener = function(self, eventName, listener)
    table.insert(self.listeners[eventName], listener)
  end

  -- Remove a listener from this world.
  -- @param listener A reference to the callback from that is called when the event is broadcast.
  inst.removeListener = function(eventName, listener)
    for i, l in ipairs(self.listeners[eventName]) do
      if l == listener then
        table.remove(i)
        return
      end
    end
  end

  -- Performs updates on data prior to frame processing. This function calls
  -- the update function of every system belonging to this world iteratively,
  -- in the order in which they were added to this world. It is expected that
  -- this function will be invoked before the world process method, once per
  -- tick, every tick.
  -- @param dt Delta time elapsed since the last tick, as a floating point number.
  inst.update = function(self, dt)
    for _, system in ipairs(self.systems) do
      system:update(dt)
    end
  end

  -- Performs frame processing. This is where all draw operations should occur,
  -- and it is assumed that all changes to data that occur this tick should
  -- have already been taken care of by calling World:update(dt).
  inst.process = function(self)
    for _, system in ipairs(self.systems) do
      system:process()
    end
  end

  return inst
end

return ring
