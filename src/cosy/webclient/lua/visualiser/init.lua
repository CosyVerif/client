-- Indeed, this is -*- Lua -*-

-- String dumper
-- -------------------------------------------------------------

function stringize (x, already_dumped_, already_dumped_indices)
   local already_dumped = already_dumped_ or {}
   local already_dumped_indices = already_dumped_indices or {}
   local type = type (x)
   if type == 'nil' then
      return 'nil'
   elseif type == 'number' then
      return (x .. "") -- Make sure that the number is converted.  Redundant?
   elseif type == 'boolean' then
      return (x and 'true' or 'false')
   elseif type == 'string' then
      return stringize_string (x)
   elseif type == 'table' then
      return stringize_table (x, already_dumped, already_dumped_indices)
   else
      return ("#<" .. type  .. ">")
   end
end

function stringize_string (s)
   res = "\""
   for i = 1, #s do
      local c = s:sub (i, i)
      if c == '\\' then
         res = res .. '\\\\'
      elseif c == '\n' then
         res = res .. '\\n'
      elseif c == '\r' then
         res = res .. '\\r'
      elseif c == '\t' then
         res = res .. '\\t'
      else
         res = res .. c
      end
   end
   res = res .. "\""
   return res
end

function stringize_table (t, already_dumped, already_dumped_indices)
   -- FIXME: assert already_dumped's and already_dumped_indices's non-nullity.
   res = ""
   local index = already_dumped [t]
   if index then
      res = res .. "#"
      res = res .. index
   else
      index = # already_dumped_indices
      already_dumped_indices [1 + index] = false
      already_dumped [t] = index
      res = res .. "#" .. index .. "{ "
      for k, v in pairs (t) do
         res = res .. stringize (k, already_dumped, already_dumped_indices)
         res = res .. ": "
         res = res .. stringize (v, already_dumped, already_dumped_indices)
         res = res .. " "
      end
      res = res .. "}"
   end
   return res
end


-- Dump to the console
-- -------------------------------------------------------------

function dump (x)
   print (stringize (x))
end


-- Core machinery
-- -------------------------------------------------------------

-- Return a zero-argument function, itself returning a fresh identifier at every
-- call.
function counterGenerator ()
   local nextUnusedValue = 0
   return
      (function ()
            local res = nextUnusedValue
            nextUnusedValue = nextUnusedValue + 1
            return res
      end)
end

-- The global counter used by every object constructor of mine at creation time.
-- This guarantees that every drawable object has a different id.
objectCounter = counterGenerator ()


-- D3 wrapper
-- -------------------------------------------------------------

-- We simply provide a global lua object called d3 wrapping what is known as d3
-- in JavaScript.  Thru this object we can just use the JavaScript API in Lua.
d3 = js.global:eval('d3')

-- Temporary globals, for me to test.
svgWidth="100%"
svgHeight="20%"
svgBackground="cyan"

-- Our picture is an SVG object, added by the code.
svg
   = d3:select("body"):append("svg")
   :attr("width", svgWidth):attr("height", svgHeight)

-- Append the arrow head definition
svg:append("defs")
   :append("marker")
   :attr("id", "arrow-head")
   :attr("markerWidth", "13")
   :attr("markerHeight", "13")
   :attr("refX", "5")
   :attr("refY", "5")
   :attr("orient", "auto")
   :append("path"):attr("d", "M0,0 L0,10 L10,5 L0,0")--:attr("style", "fill: #0000ff")

-- SVGs can have no background color, as far as I see.  But the workaround is
-- easy: the bottom object drawn in the SVG will be a rectangle, taking all the
-- space.
svgBackground
   = svg:append("rect"):attr("width", "100%")
   :attr("height", "100%"):attr("fill", svgBackground)


-- OO machinery
-- -------------------------------------------------------------

-- This new method is shared by all my classes.
function new (self, o)
   o = o or {}
   setmetatable (o, self)
   self.__index = self
   self.id = objectCounter ()
   if self.init then
      self:init ()
   end
   return o
end

-- The init method, if defined for a class, serves to initialize optional fields
-- not directly set by the table passed thru new to their default values.  init
-- is automatically called by new.

-- By convention, unimplemented methods in abstract classes are
-- defined like this.  For unimplemented fields we just use nil.
function abstract (self)
   error "abstract"
end

-- A base class Thing is defined as:
--   Thing = { new = new, FIELDASSIGNMENTS}
-- A subclass of Thing is defined as:
--   Subthing = Thing:new ({FIELDASSIGNMENTS})


-- OO Scratch
-- -------------------------------------------------------------

print ("=== OO Scratch")

Person = {
   new = new,
   greet = function (self)
      print ("Hello, I am " .. (self.name or "unnamed")
                .. " and my id is "
                .. self.id
                .. ".")
   end
}

Student = Person:new ()
function Student:greet ()
   Person.greet (self)
   print ("By the way, I'm also a student -- " .. (self.name or "unnamed"))
end

luca = Person:new ({name = 'Luca'})
luca:greet ()
john = Person:new ({name = 'John'})
john:greet ()
alexandre = Student:new ({name = 'Alexandre'})
alexandre:greet ()


-- Core graphic classes
-- -------------------------------------------------------------

print ("=== Core graphic classes ")

-- A Drawable is anything which can be drawn.
Drawable = {
   new = new,
   draw = abstract
}


-- Graph
-- -------------------------------------------------------------

-- A graph is a drawable thing, containing nodes and edges.
Graph = Drawable:new ()
function Graph:init ()
   self.nodes = self.nodes or {}
   self.edges = self.edges or {}
   self.children = self.children or {}
   print ("Initializing a new graph " .. stringize (self))
end

-- Drawing a graph means drawing all of its children.
function Graph:draw ()
   for _, child in ipairs (self.children) do
      if child.draw then
         print ("drawing child")
         child:draw ()
      else
         print ("WARNING: child not drawable: " .. stringize (child))
      end
   end
end

-- Add a given child to a given graph, and return the child.
function Graph:addChild (n)
   self.children[#self.children + 1] = n
   n.parent = self
   return n
end

-- FIXME: frames.


-- Node
-- -------------------------------------------------------------

-- A node is simply a drawable object with a few attributes.
Node = Drawable:new ()
function Node:init ()
   self.shape = self.shape or "circle"
   self.fill = self.fill or "red"
   self.radius = self.radius or "3"
   self.text = self.text or ""
end

-- Draw self, and return it
function Node:draw ()
   svg:append(self.shape)
      :attr("cx", self.x .. "%")
      :attr("cy", self.y  .. "%")
      :attr("r", self.radius .. "%")
      :attr("fill", self.fill)
   svg:append("text")
      :attr("text-anchor", "middle")
      :attr("alignment-baseline", "central")
      :attr("x", self.x .. "%")
      :attr("y", self.y .. "%")
      :text(self.text)
   return self
end

-- Add a given node to a given graph, and return the node.
function Graph:addNode (n)
   print ("Adding the new node " .. n.id .. " to graph " .. self.id)
   self.nodes[#self.nodes + 1] = self:addChild(n)
   return n
end


-- Edge
-- -------------------------------------------------------------

-- Add a given edge to a given graph, and return the node.
function Graph:addEdge (n)
   print ("Adding the new edge " .. n.id .. " to graph " .. self.id)
   self.edges[#self.edges + 1] = self:addChild(n)
   return n
end


-- Driver test
-- -------------------------------------------------------------

g = Graph:new ({name = "g"})
g2 = Graph:new ({name = "g2"})

n1 = g:addNode (Node:new ({x = 10, y = 20, text = "n1" }))
n2 = g:addNode (Node:new ({x = 50, y = 20, text = "n2", fill = "orange"}))
n3 = g:addNode (Node:new ({x = 30, y = 50}))

g2:draw ()

print ("g is  " .. stringize (g))
print ("g2 is " .. stringize (g2))
print ("n1 is  " .. stringize (n1))

print ("Graph is " .. stringize (Graph)) -- This shows that something is obviously wrong
print ("Node is " .. stringize (Graph)) -- This shows that something is obviously wrong

svg:append("line")
   :attr("x1", "50%"):attr("y1", "75%")
   :attr("x2", "75%"):attr("y2", "50%")
   :attr("stroke", "black")
   :attr("stroke-width", "2")
   :attr("marker-end", "url(#arrow-head)")

print ("Graph is " .. stringize (Graph))

dump("Person is " .. stringize (Person))
dump("Student is " .. stringize (Student))

