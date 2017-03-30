-- This file contains testing, obsolete, broken or unused code.
-- -------------------------------------------------------------

-- Alban says that this has some fundamental flaw.  It's probably not terrbily
-- important, since the web client now adopts a different, simpler solution.

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

-- Core graphic classes
-- -------------------------------------------------------------

print ("=== Core graphic classes ")

-- A Drawable is anything which can be drawn.
Drawable = {
   new = new,
   draw = abstract
}

-- Driver test
-- -------------------------------------------------------------

-- ???
if false then
   g = Graph:new ({name = "g"})
   n1 = g:addNode (Node:new ({x = 10, y = 20, text = "n1" }))
   n2 = g:addNode (Node:new ({x = 50, y = 20, text = "n2", fill = "orange"}))
   n3 = g:addNode (Node:new ({x = 30, y = 50}))
   g:draw ()
end
