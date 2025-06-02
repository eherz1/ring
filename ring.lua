--- An entity component system implementation (ECS) for lua.
-- @module ring
local ring = {}

ring.COMPONENT_PREFIX = "@"
ring.ENTITY_PREFIX = "#"
ring.ADD_SUFFIX = "+"
ring.SUBTRACT_SUFFIX = "-"
ring.CHANGE_SUFFIX = "~"

-- Credits to http://lua-users.org/lists/lua-l/2006-12/msg00414.html
ring.stringSplit = function(s, pat)
  local st, g = 1, s:gmatch("()(" .. pat .. ")")
  local function getter(self, segs, seps, sep, cap1, ...)
    st = sep and seps + #sep
    return s:sub(segs, (seps or 0) - 1), cap1 or sep, ...
  end
  local function splitter(self)
    if st then return getter(s, st, g()) end
  end
  return splitter, s
end

--- Create a new `ring.Entity` table.
-- @tfield string name The name of the entity.
ring.newEntity = function(name, components)
  return { name = name, components = components }
end

--- A definition of a `ring.System`.
-- @table SystemDefinition
-- @tfield ()=>void initialize An optional function which will be called when the system is added to a world.
-- @tfield ()=>void destroy An optional function which will be called when the system is removed from a world.
-- @tfield (delta)=>void update A required function that computes updates before frame processing.
-- @tfield ()=>void process A required function which does per-frame processing.
ring.SystemDefinition = {}

--- A system implementation.
-- @table System
-- @tfield ()=>void initialize An optional function which will be called when the system is added to a world.
-- @tfield ()=>void destroy An optional function which will be called when the system is removed from a world.
-- @tfield (dt)=>void update A required function which performs updates before frame processing.
-- @tfield ()=>void process A required function which performs per-frame processing.
ring.System = {}

--- Create a new `ring.System` table.
-- @function newSystem
-- @tparam ring.SystemDefinition definition A `ring.SystemDefinition` table.
-- @treturn ring.System A `ring.System` table.
ring.newSystem = function(definition)
  local b = {}

  for k, v in pairs(definition) do b[k] = v end

  b.initialize = definition.initialize or function(self)
  end

  b.destroy = definition.destroy or function(self)
  end

  b.update = definition.update or function(self, dt)
    error("SystemDefinition.update must be implemented")
  end

  b.process = definition.process or function(self)
    error("SystemDefinition.process must be implemented")
  end

  return b
end

--- A definition of a `EventSystem`.
-- @table EventSystemDefinition
-- @tfield {{subject, callback},...} listeners A set of subjects to listen to.
-- @tfield ()=>void initialize Optional function which will be called when the system is initialized.
-- @tfield ()=>void destroy Optional function which will be called when the system is destroyed.
ring.EventSystemDefinition = {}

--- An event system implementation.
-- EventSystem is a system that is primarily interested in responding to
-- events that occur on the world to which the system belongs. It accepts a
-- set of subjects mapped to callback functions, the subjects of which will be
-- subscribed to automatically during initialization and unsubscribed from
-- during destruction. The system may implement update and process functions
-- as well, but these are considered optional.
ring.EventSystem = {}

--- Create a new `ring.EventSystem` table.
-- @tparam ring.EventSystemDefinition definition A `ring.EventSystemDefinition` table.
ring.newEventSystem = function(definition)
  local b = {}

  b.subscriptions = {}

  for k, v in pairs(definition) do b[k] = v end

  local subscribe = function(self, subject, callback)
    self.subscriptions[callback] = self.world:subscribe(subject, function(...)
      callback(self, ...)
    end)
  end

  local unsubscribe = function(self, subject, callback)
    subscriptions[callback] = self.world:unsubscribe(subject,
                                                     subscriptions[callback])
  end

  b.initialize = function(self)
    for subject, callback in pairs(self.listeners) do
      subscribe(self, subject, callback)
    end

    if definition.initialize then definition.initialize(self) end
  end

  b.destroy = function(self)
    for subject, callback in pairs(self.listeners) do
      unsubscribe(self, subject, callback)
    end

    if definition.destroy then definition.destroy(self) end
  end

  b.update = definition.update or function(self, dt)
  end

  b.process = definition.process or function(self)
  end

  return b
end

--- A definition of a `ring.EntitySystem`.
-- @table EntitySystemDefinition
-- @tfield ()=>void initialize An optional function which will be called when the system is added to a world.
-- @tfield ()=>void destroy An optional function which will be called when the system is removed from a world.
-- @tfield (entityId)=>void Required function which will be called once per-entity to perform updates before per-frame processing.
-- @tfield (entityId)=>void Required function which will be called once per-entity to perform per-frame processing.
ring.EventSystemDefinition = {}

--- An entity system implementation.
-- An entity system keeps a set of entity IDs and calls its `updateEntity`
-- and `processEntity` functions iteratively for each entity ID in the set.
-- Membership in the set is determined by a call to `matchEntity` on the
-- following events,
-- (1) `"+#"` aka `entity created`,
-- (2) `"-#"` aka `entity destroyed`,
-- (3) `"+@"` aka `component added`,
-- (4) `"-@"` aka `component removed`.
-- @table EntitySystem
-- @tfield ()=>void initialize An optional function which will be called when the system is added to a world.
-- @tfield ()=>void destroy An optional function which will be called when the system is removed from a world.
-- @tfield (dt,entityId)=>void updateEntity A required function which performs updates before frame processing on all matching entities.
-- @tfield ()=>void processEntity A required function which performs per-frame processing on all matching entities.
ring.EntitySystem = {}

--- Create a new `ring.EntitySystem` table.
-- @tparam EntitySystemDefinition definition A `ring.EntitySystemDefinition` table.
-- @treturn EntitySystem A `ring.EntitySystem` table.
ring.newEntitySystem = function(definition)
  local b = {}

  for k, v in pairs(definition) do b[k] = v end

  b.entities = {}

  local recomputeMembership = function(self, e)
    self.entities[e] = self:matchEntity(e) or nil
  end

  b.initialize = function(self)
    for _, e in pairs(self.world.entities) do
      self.entities[e] = self:matchEntity(e)
    end

    self.world:subscribe("+#", function(e)
      recomputeMembership(self, e)
    end)

    self.world:subscribe("-#", function(e)
      recomputeMembership(self, e)
    end)

    self.world:subscribe("+@", function(e)
      recomputeMembership(self, e)
    end)

    self.world:subscribe("-@", function(e)
      recomputeMembership(self, e)
    end)

    if definition.initialize then definition.initialize(self) end
  end

  b.destroy = function(self)
    self.world:unsubscribe("+#", self.recomputeMembership)
    self.world:unsubscribe("-#", self.recomputeMembership)
    self.world:unsubscribe("+@", self.recomputeMembership)
    self.world:unsubscribe("-@", self.recomputeMembership)

    if definition.destroy then definition.destroy(self) end
  end

  b.matchEntity = definition.matchEntity or function(self, e)
    error("EntitySystemDefinition.matchEntity must be implemented")
  end

  b.updateEntity = definition.updateEntity or function(self, e, dt)
    error("EntitySystemDefinition.updateEntity must be implemented")
  end

  b.update = function(self, dt)
    for e, _ in pairs(self.entities) do self:updateEntity(e, dt) end

    if definition.update then definition.update(self, dt) end
  end

  b.processEntity = definition.processEntity or function(self, entityId)
    error("EntitySystemDefinition.processEntity must be implemented")
  end

  b.process = function(self)
    for e, _ in pairs(self.entities) do self:processEntity(e) end

    if definition.process then definition.process(self) end
  end

  return b
end

--- A `ring.MessageBus` style subject string.
ring.SubjectString = {}

--- Split a `ring.SubjectString` into a `ring.SubjectParts` array.
-- @tparam ring.SubjectString subject The subject to listen to.
ring.subjectToParts = function(subject)
  local parts = {}

  local char1 = string.sub(subject, 1, 1)

  -- When referring to a built-in change modifier, allow prefixing
  -- the modifier, and ring will automatically use it as the leaf
  -- node.
  -- For example, '+@component' will become '@component.+'
  if char1 == "+" or char1 == "-" or char1 == "~" or char1 == "!" then
    subject = string.sub(subject, 2) .. "." .. char1
    char1 = string.sub(subject, 1, 1)
  end

  -- for part, delim in ring.stringSplit(subject, "([^\\.\\@\\#]+)") do
  for part, delim in ring.stringSplit(subject, "[\\.|(@)|(#)]") do
    if part ~= "" then table.insert(parts, part) end
    if delim == "@" or delim == "#" then table.insert(parts, delim) end
  end

  return parts
end

local newMessageBusNodeContainer = {}

newMessageBusNodeContainer.newMessageBusNode = function()
  local b = {}

  b.children = {}
  b.listeners = {}

  local getOrCreateNodeContainer = {}

  getOrCreateNodeContainer.getOrCreateNode =
      function(self, name)
        local node = self.children[name]
        if not node then
          node = newMessageBusNodeContainer.newMessageBusNode(self)
          self.children[name] = node
        end
        return node
      end

  local copyParts = function(self, parts)
    local copy = {}
    for i, v in ipairs(parts) do copy[i] = v end
    return copy
  end

  local subscribePartsContainer = {}

  subscribePartsContainer.subscribeParts =
      function(self, parts, callback)
        if #parts == 0 then
          self.listeners[callback] = callback
        else
          local nextPart = table.remove(parts, 1)
          local nextNode =
              getOrCreateNodeContainer.getOrCreateNode(self, nextPart)
          subscribePartsContainer.subscribeParts(nextNode, parts, callback)
        end
        return callback
      end

  b.subscribeParts = function(self, parts, callback)
    -- print("SUBSCRIBING TO " .. table.concat(parts, "."))
    return subscribePartsContainer.subscribeParts(self, copyParts(self, parts),
                                                  callback)
  end

  b.subscribe = function(self, subject, callback)
    return self:subscribeParts(ring.subjectToParts(subject), callback)
  end

  local unsubscribeParts = function(self, parts, callback)
    if #parts == 0 then
      self.listeners[callback] = nil
    else
      local nextPart = table.remove(parts, 1)
      local nextNode = getOrCreateNodeContainer.getOrCreateNode(self, nextPart)
      return unsubscribeParts(nextNode, parts, callback)
    end
    return callback
  end

  b.unsubscribe = function(self, subject, callback)
    return unsubscribeParts(self, self:subjectToParts(self, subject), callback)
  end

  local publishParts = function(self, parts, ...)
    if #parts == 0 then
      for listener, _ in pairs(self.listeners) do listener(...) end
    else
      local nextPart = table.remove(parts, 1)
      if #parts == 0 and nextPart ~= "*" then
        local starNode = getOrCreateNodeContainer.getOrCreateNode(self, "*")
        self.publishParts(starNode, parts, ...)
      end
      local nextNode = getOrCreateNodeContainer.getOrCreateNode(self, nextPart)
      self.publishParts(nextNode, parts, ...)
    end
  end

  b.publishParts = function(self, parts, ...)
    publishParts(self, copyParts(self, parts), ...)
  end

  b.publish = function(self, subject, ...)
    publishParts(self, self:subjectToParts(subject), ...)
  end

  return b
end

--- A message bus implementation.
-- @table MessageBus
-- @tfield (subject,message)=>void publish
-- @tfield (subject,callback)=>void subscribe
ring.MessageBus = {}

--- Create a new `ring.MessageBus` table.
ring.newMessageBus = function()
  local b = {}

  b.root = newMessageBusNodeContainer.newMessageBusNode()

  b.subscribe = function(self, subject, callback)
    return self.root:subscribe(subject, callback)
  end

  b.subscribeParts = function(self, parts, callback)
    return self.root:subscribeParts(parts, callback)
  end

  b.unsubscribe = function(self, subject, callback)
    return self.root:unsubscribe(subject, callback)
  end

  b.publishParts = function(self, parts, ...)
    self.root:publishParts(parts, ...)
  end

  b.publish = function(self, subject, ...)
    self.root:publish(subject, ...)
  end

  return b
end

--- A world implementation.
-- World represents a context in which a set of entities
-- with various compositional components are acted upon by a ordered set of
-- of systems.
-- @table World
-- @tfield (subject,callback)=>void subscribe Subscribe to a `ring.SubjectString`.
-- @tfield (subject,callback)=>void unsubscribe Unsubscribe from a `ring.SubjectString`.
-- @tfield (subject,message)=>void publish Publish a message to a `ring.SubjectString`.
-- @tfield (entityId,componentName,value)=>void putComponent Add a component to an entity. The form of a component is unstructured, but if values are provided, the component will be initialized with those values. Otherwise, the component will be initialized to boolean 'true'. *Aliases: putc,addComponent,addc.*
-- @tfield (entityId,componentName)=>void deleteComponent Delete a component from an entity. *Aliases: delc,removeComponent,remc.*
-- @tfield (entityId,componentName,[componentKey])=>void getComponent Get a copy of a component value or a copy of the entire component table. *Aliases: getc.*
-- @tfield (entityId,componentName)=>boolean hasComponent Check whether a entity has a component.
-- @tfield ({componentName,defaults},...},[name])=>void createEntity Create an entity.
-- @tfield (name)=>void getEntity Get an entity by name.
-- @tfield (entityId)=>void destroyEntity Destroy an entity.
-- @tfield (system,[name])=>void addSystem Add a system to this world.
-- @tfield (name)=>void getSystem Get a system from this world.
-- @tfield (systemOrName)=>void removeSystem Remove a system from this world.
-- @tfield (dt)=>void update Perform world updates.
-- @tfield ()=>void process Perform world per-frame processing.
ring.World = {}

--- Create a new `ring.World` table.
-- @treturn World A `ring.World` table.
ring.newWorld = function(isPublish)
  isPublish = isPublish ~= nil and isPublish or true

  local b = {}

  b.bus = ring.newMessageBus()
  b.components = {}
  b.componentMetadata = {}
  b.entityDefinitions = {}
  b.entities = {}
  b.entityMetadata = {}
  b.nameToEntity = {}
  b.entityToName = {}
  b.nameToSystem = {}
  b.systems = {}

  local componentSubjects = {
    add = { ring.COMPONENT_PREFIX, ring.ADD_SUFFIX },
    subtract = { ring.COMPONENT_PREFIX, ring.SUBTRACT_SUFFIX }
  }

  local entitySubjects = {
    add = { ring.ENTITY_PREFIX, ring.ADD_SUFFIX },
    subtract = { ring.ENTITY_PREFIX, ring.SUBTRACT_SUFFIX }
  }

  -- Metadata

  local makeComponentMetadata = function(self, c)
    return {
      subjects = {
        add = { ring.COMPONENT_PREFIX, c, ring.ADD_SUFFIX },
        change = { ring.COMPONENT_PREFIX, c, ring.CHANGE_SUFFIX },
        subtract = { ring.COMPONENT_PREFIX, c, ring.SUBTRACT_SUFFIX }
      }
    }
  end

  local makeEntityMetadata = function(self, e, n)
    local subjects = {}
    subjects.add = { ring.ENTITY_PREFIX, e, ring.ADD_SUFFIX }
    subjects.change = { ring.ENTITY_PREFIX, e, ring.CHANGE_SUFFIX }
    subjects.subtract = { ring.ENTITY_PREFIX, e, ring.SUBTRACT_SUFFIX }
    if n then
      subjects.namedAdd = { ring.ENTITY_PREFIX, n, ring.ADD_SUFFIX }
      subjects.namedChange = { ring.ENTITY_PREFIX, n, ring.CHANGE_SUFFIX }
      subjects.namedSubtract = { ring.ENTITY_PREFIX, n, ring.SUBTRACT_SUFFIX }
    end
    subjects.components = {}
    return { subjects = subjects }
  end

  local makeEntityComponentMetadata = function(self, e, n, c)
    local subjects = {}
    subjects.add = {
      ring.ENTITY_PREFIX, e, ring.COMPONENT_PREFIX, c, ring.ADD_SUFFIX
    }
    subjects.change = {
      ring.ENTITY_PREFIX, e, ring.COMPONENT_PREFIX, c, ring.CHANGE_SUFFIX
    }
    subjects.subtract = {
      ring.ENTITY_PREFIX, e, ring.COMPONENT_PREFIX, c, ring.SUBTRACT_SUFFIX
    }
    if n then
      subjects.namedAdd = {
        ring.ENTITY_PREFIX, n, ring.COMPONENT_PREFIX, c, ring.ADD_SUFFIX
      }
      subjects.namedChange = {
        ring.ENTITY_PREFIX, n, ring.COMPONENT_PREFIX, c, ring.CHANGE_SUFFIX
      }
      subjects.namedSubtract = {
        ring.ENTITY_PREFIX, n, ring.COMPONENT_PREFIX, c, ring.SUBTRACT_SUFFIX
      }
    end
    return subjects
  end

  local createComponentMetadata = function(self, c)
    self.componentMetadata[c] = makeComponentMetadata(self, c)
  end

  local createEntityMetadata = function(self, e, n)
    self.entityMetadata[e] = makeEntityMetadata(self, e, n)
  end

  local destroyEntityMetadata = function(self, e)
    self.entityMetadata[e] = nil
  end

  local createEntityComponentMetadata = function(self, e, n, c)
    self.entityMetadata[e].subjects.components[c] =
        makeEntityComponentMetadata(self, e, n, c)
  end

  local destroyEntityComponentMetadata =
      function(self, e, c)
        self.entityMetadata[e].subjects.components[c] = nil
      end

  -- Component Helpers

  local createComponent = function(self, c)
    local component = {}
    self.components[c] = component
    createComponentMetadata(self, c)
    return component
  end

  local deleteComponent = function(self, c)
    self.components[c] = nil
    self.componentMetadata[c] = nil
  end

  local getOrCreateComponent = function(self, c)
    local component = self.components[c]
    if not component then return createComponent(self, c) end
    return component
  end

  -- Entity Helpers

  local entityId = function(self, e)
    return type(e) == "number" and e or self.nameToEntity[e]
  end

  local entityName = function(self, e)
    return type(e) == "string" and e or self.entityToName[e] or e
  end

  -- Message Bus

  b.subscribe = function(self, subject, callback)
    return self.bus:subscribeParts(self:subjectToParts(subject), callback)
  end

  b.unsubscribe = function(self, subject, callback)
    return self.bus:unsubscribe(subject, callback)
  end

  local unprotectedPublishParts = function(self, parts, ...)
    return self.bus:publishParts(parts, ...)
  end

  local unprotectedPublish = function(self, subject, ...)
    return self.bus:publish(subject, ...)
  end

  b.subjectToParts = function(self, subject)
    local parts = ring.subjectToParts(subject)

    -- If the subject refers to an entity by name, then replace the name
    -- with the entity's ID.
    -- if #parts > 1 and parts[1] == "#" and string.match(parts[2], "%w+") then
    --   local n = self.nameToEntity[parts[2]]
    --   if n then
    --     parts[2] = n
    --   end
    -- end

    return parts
  end

  b.publishParts = function(self, parts, ...)
    return self.bus:publishParts(parts, ...)
  end

  b.publish = function(self, subject, ...)
    self:publishParts(self:subjectToParts(subject), ...)
  end

  -- Add Component

  local publishComponentAdd = function(self, e, c, t)
    unprotectedPublishParts(self, entitySubjects.add, e)
    unprotectedPublishParts(self, self.componentMetadata[c].subjects.add, e, t)

    -- local entitySubjects = self.entityMetadata[e].subjects
    -- unprotectedPublishParts(self, entitySubjects.change, c, t)
    -- if entitySubjects.namedChange then
    --   unprotectedPublishParts(self, entitySubjects.namedChange, c, t)
    -- end

    -- local entityComponentSubjects = entitySubjects.components[c]
    -- unprotectedPublishParts(self, entityComponentSubjects.add, t)
    -- if entityComponentSubjects.namedAdd then
    --   unprotectedPublishParts(self, entityComponentSubjects.namedAdd, t)
    -- end
  end

  local addComponentPure = function(self, e, c, t)
    t = t or {}

    local component = getOrCreateComponent(self, c)
    if component[e] then
      error("World.addComponent cannot be called for existing component: " .. c)
    end

    component[e] = t
    createEntityComponentMetadata(self, e, self:getEntityName(e), c)
    return t
  end

  local addComponent = function(self, e, c, t)
    local r = addComponentPure(self, e, c, t)
    publishComponentAdd(self, e, c, t)
    return r
  end

  b.addComponent = isPublish and addComponent or addComponentPure

  -- Set Component

  local publishComponentSet = function(self, e, c, t, value)
    unprotectedPublishParts(self, self.componentMetadata[c].subjects.change, e,
                            t)

    local entitySubjects = self.entityMetadata[e].subjects
    unprotectedPublishParts(self, entitySubjects.change, t)
    if entitySubjects.namedChange then
      unprotectedPublishParts(self, entitySubjects.namedChange, t)
    end

    local entityComponentSubjects = entitySubjects.components[c]

    unprotectedPublishParts(self, entityComponentSubjects.change, t)
    if entityComponentSubjects.namedChange then
      unprotectedPublishParts(self, entityComponentSubjects.namedChange, t)
    end
  end

  local setComponentPure = function(self, e, c, t, value)
    local component = getOrCreateComponent(self, c)
    local entityComponent = component[e]

    if not entityComponent then
      error(
          "World.setComponent cannot be called for non-existing component '" ..
              c .. "' of #" .. entityName(self, e))
    end

    if type(t) == "table" then
      for k, v in pairs(t) do entityComponent[k] = v end
      return entityComponent
    else
      entityComponent[t] = value
      return value
    end
  end

  local setComponent = function(self, e, c, t, value)
    setComponentPure(self, e, c, t, value)
    publishComponentSet(self, e, c, t, value)
  end

  b.setComponent = isPublish and setComponent or setComponentPure

  -- Get Component

  b.getComponent = function(self, e, c, k)
    local component = getOrCreateComponent(self, c)
    local entityComponent = component[e]

    if not entityComponent then return nil end

    local value = k ~= nil and entityComponent[k] or entityComponent

    return value
  end

  b.hasComponent = function(self, e, c)
    local component = self.components[c]
    return component and component[e] ~= nil
  end

  -- Remove Component

  local publishComponentRemove = function(self, e, c)
    unprotectedPublishParts(self, self.componentMetadata[c].subjects.subtract, e)

    local entitySubjects = self.entityMetadata[e].subjects

    unprotectedPublishParts(self, entitySubjects.subtract, c)
    if entitySubjects.namedSubtract then
      unprotectedPublishParts(self, entitySubjects.namedSubtract, c)
    end

    local entityComponentSubjects = entitySubjects.components[c]
    -- unprotectedPublishParts(self, entityComponentSubjects.subtract);
    -- if entityComponentSubjects.namedSubtract then
    --   unprotectedPublishParts(self, entityComponentSubjects.namedSubtract);
    -- end
  end

  local removeComponentPure = function(self, e, c)
    local component = self.components[c]
    if not component then
      error("Cannot remove non-existing component '" .. c .. "' of #" .. e)
    end

    component[e] = nil
    destroyEntityComponentMetadata(self, e, c)
    return component
  end

  local removeComponent = function(self, e, c)
    -- publishComponentRemove(self, e, c)
    return removeComponentPure(self, e, c)
  end

  b.removeComponent = isPublish and removeComponent or removeComponentPure

  -- Create Entity

  local entityIdCounter = 0

  local nextEntityId = function()
    entityIdCounter = entityIdCounter + 1
    return entityIdCounter
  end

  local setEntityName = function(self, e, n)
    self.nameToEntity[n] = e
    self.entityToName[e] = n
  end

  local clearEntityName = function(self, e, n)
    self.nameToEntity[n] = nil
    self.entityToName[e] = nil
  end

  local publishEntityCreate = function(self, e)
    unprotectedPublishParts(self, entitySubjects.add, e)
    -- local entitySubjects = self.entityMetadata[e].subjects
    -- unprotectedPublishParts(self, entitySubjects.add)
    -- if entitySubjects.namedAdd then
    --   unprotectedPublishParts(self, entitySubjects.namedAdd)
    -- end
  end

  local createEntityPure = function(self, componentsOrName, components)
    if type(componentsOrName) == "table" then components = componentsOrName end

    local e = nextEntityId()
    self.entities[e] = true

    local n = nil
    if type(componentsOrName) == "string" then
      n = componentsOrName
      setEntityName(self, e, n)
    end

    createEntityMetadata(self, e, n)

    if components ~= nil then
      for c, t in pairs(components) do self:addComponent(e, c, t) end
    end

    return e
  end

  local createEntity = function(self, componentsOrName, components)
    local e = createEntityPure(self, componentsOrName, components)
    publishEntityCreate(self, e)
    return e
  end

  b.createEntity = isPublish and createEntityPure or createEntity

  -- Get Entity

  b.getEntity = function(self, name)
    return self.nameToEntity[name]
  end

  b.getEntityName = function(self, e)
    return self.entityToName[e]
  end

  -- Destroy Entity

  local publishEntityDestroy = function(self, e)
    local entitySubjects = self.entityMetadata[e].subjects
    unprotectedPublishParts(self, entitySubjects.subtract)
    if entitySubjects.namedSubtract then
      unprotectedPublishParts(self, entitySubjects.namedSubtract)
    end
  end

  local destroyEntityPure = function(self, e)
    self.entities[e] = nil
    removeEntityMetadata(self, e)
  end

  local destroyEntity = function(self, e)
    destroyEntityPure(self, e)
    publishEntityDestroy(self, e)
  end

  b.destroyEntity = isPublish and destroyEntity or destroyEntityPure

  -- Add System

  b.addSystem = function(self, systemOrName, system)
    if type(systemOrName) == "table" then
      system = systemOrName
    else
      self.nameToSystem[systemOrName] = system
    end

    system.world = self

    table.insert(self.systems, system)

    system:initialize()
  end

  local findIndexOfSystem = function(self, system)
    for i, s in ipairs(self.systems) do if s == system then return i, s end end
    return -1, system
  end

  b.removeSystem = function(self, systemOrName)
    local i, system = type(systemOrName) == "table" and
                          findIndexOfSystem(self, systemOrName) or
                          findIndexOfSystem(self, nameToSystem[systemOrName])
    table.remove(self.systems, i)
    system:destroy()
  end

  b.getSystem = function(self, name)
    return self.nameToSystem[name]
  end

  -- Performs updates on data prior to frame processing. This function calls
  -- the update function of every system belonging to this world iteratively,
  -- in the order in which they were added to this world. It is expected that
  -- this function will be invoked before the world process method, once per
  -- tick, every tick.
  -- @param dt Delta time elapsed since the last tick, as a floating point number.
  b.update = function(self, dt)
    for _, system in ipairs(self.systems) do system:update(dt) end
  end

  -- Performs frame processing. This is where all draw operations should occur,
  -- and it is assumed that all changes to data that occur this tick should
  -- have already been taken care of by calling World:update(dt).
  b.process = function(self)
    for _, system in ipairs(self.systems) do system:process() end
  end

  return b
end

return ring
