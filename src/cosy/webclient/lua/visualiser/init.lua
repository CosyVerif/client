-- Indeed, this is -*- Lua -*-

--[[ Scratch VNC
Set first RandR output resolution (on moore):
  xrandr --output eDP1 --mode 1152x864

Forward VNC port from ageinghacker.net to moore (on moore):
  ssh -4R '*:5900:*:5900' luca@ageinghacker.net

Forward HTTP port from ageinghacker.net to moore (on moore):
  ssh -4R '*:9000:*:80' luca@ageinghacker.net

Start the VNC server (on moore):
#  x11vnc -viewonly -verbose -usepw -no6 -noipv6 -ncache 10 -shared -forever -display :0 -xinerama -nodpms -threads -overlay -clip xinerama0
  x11vnc -verbose -usepw -no6 -noipv6 -ncache 10 -shared -forever -display :0 -xinerama -nodpms -threads -overlay -clip xinerama0
--]]


-- Stuff to look into
-- -------------------------------------------------------------

--[[
SVG coordinates
  http://tutorials.jenkov.com/svg/svg-coordinate-system.html (likely the quickest doc to check)
  http://commons.oreilly.com/wiki/index.php/SVG_Essentials/Coordinates
  https://www.w3.org/TR/SVG/coords.html
--]]


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
   local res = "\""
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
   require (already_dumped)
   require (already_dumped_indices)

   local res = ""
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
         res = res .. ", "
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


-- Timing (for benchmarking)
-- -------------------------------------------------------------

function time_now ()
   return js.global:eval('new Date().getTime()')
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
arrow_head_width = 5
arrow_head_height = 3.5
svg:append("defs")
   :append("marker")
   :attr("id", "arrow-head")
   --:attr("markerWidth", "13"):attr("markerHeight", "13")
   :attr("markerWidth", arrow_head_width):attr("markerHeight", arrow_head_height)
   --:attr("refX", "10"):attr("refY", "5")
   --:attr("refX", "5"):attr("refY", "5")
   :attr("refX", arrow_head_width):attr("refY", arrow_head_height / 2.0)
   :attr("orient", "auto")
   --:append("path"):attr("d", "M0,0 L0,10 L10,5 L0,0")
   --:append("path"):attr("d", "M0,0 L10,5 L10,5 Z")
   :append("path"):attr("d", "M0,0 L0,"..arrow_head_height.." L"..arrow_head_width..","..(arrow_head_height/2.0).." Z")
   --:attr("style", "fill: #0000ff")
   --:attr("style", "stroke-width: 5px")
   --:attr("style", "fill: green")

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


-- Trivial utility functions: arithmetic, comparisons.
-- -------------------------------------------------------------

-- Given two comparable Lua objects return the smaller one according to _ < _.
function min (a, b)
   if a < b then
      return a
   else
      return b
   end
end

-- Given two comparable Lua objects return the larger one according to _ < _.
function max (a, b)
   if a > b then
      return a
   else
      return b
   end
end

function average (first, ...)
   local length = 1.0
   local sum = first
   for _, k in pairs ({...}) do
      length = length + 1
      sum = sum + k
   end
   return sum / length
end

function square (x)
   return x * x
end

-- Lua is happy to use "inf" and "-inf" in its output syntax, but has no "inf"
-- literal.  This makes working with infinities nicer.
inf = 1 / 0


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

-- ???
if false then
   g = Graph:new ({name = "g"})
   n1 = g:addNode (Node:new ({x = 10, y = 20, text = "n1" }))
   n2 = g:addNode (Node:new ({x = 50, y = 20, text = "n2", fill = "orange"}))
   n3 = g:addNode (Node:new ({x = 30, y = 50}))
   g:draw ()
end

-- print ("g is  " .. stringize (g))
-- print ("g2 is " .. stringize (g2))
-- print ("n1 is  " .. stringize (n1))

-- print ("Graph is " .. stringize (Graph)) -- This shows that something is obviously wrong
-- print ("Node is " .. stringize (Graph)) -- This shows that something is obviously wrong

-- svg:append("line")
--    :attr("x1", "50%"):attr("y1", "75%")
--    :attr("x2", "75%"):attr("y2", "50%")
--    :attr("stroke", "black")
--    :attr("stroke-width", "2")
--    :attr("marker-end", "url(#arrow-head)")

-- print ("Graph is " .. stringize (Graph))

-- dump("Person is " .. stringize (Person))
-- dump("Student is " .. stringize (Student))


-- New scratch
-- -------------------------------------------------------------

-- This will be useful later.  The important information is simply the "refX" attribute name.
-- http://stackoverflow.com/questions/16660193/get-arrowheads-to-point-at-outer-edge-of-node-in-d3


-- Errors and warnings
-- -------------------------------------------------------------

-- Print a well-visible messaage.
function warn (string)
   error ("WARNING: " .. string)
end

-- Print a well-visible messaage and fail with an error which is not supposed to be handled.
function fatal (string)
   error ("FATAL ERROR: " .. string)
end

-- Display an unimplemented feature message, either as a warning or as an error.
function warn_unimplemented (string)
   error ("WARNING: unimplemented: " .. string)
end
function unimplemented (string)
   error ("UNIMPLEMENTED: " .. string)
end

-- Mark code which is supposed to be unreachable.
function unreachable ()
   fatal ("supposedly unreachable code was reached")
end

function require (condition)
   if not condition then
      fatal ("requirement failed");
   end
end


-- Table-as-set utility
-- -------------------------------------------------------------

-- A simple implementation of sets as tables with index keys, and element
-- comparison by identity.
-- The index keys are contiguous, 1-based automatically maintained integers.

-- Return a fresh empty set.
function set_make_empty ()
   return {}
end

-- Return non-false iff the given set is empty.
function set_is_empty (set)
   return #set == 0
end

function set_has (set, element)
   for _, an_element in ipairs (set) do
      if element == an_element then
         return true
      end
   end
   return false
end

-- Destructively append one element to set.
function set_add (set, element)
   if not set_has (set, element) then
      set [#set + 1] = element
   end
   return set
end

-- Destructively remove element to set.
function set_remove (set, element)
   for an_index, an_element in ipairs (set) do
      if an_element == element then
         local old_size = #set
         for index = an_index, old_size do
            -- This does the right thing for the last index, whose corresponding
            -- datum will be set to nil.
            set [index] = set [index + 1]
         end
         return set
      end
   end
   return set
end

-- FIXME: here I could have fun with metatables and define operators, but that
-- feels kinda pointless.  I'll do it if I use sets a lot and the code needs to
-- get more compact.


-- Coordinates
-- -------------------------------------------------------------

-- Cartesian coordinates are numbers in [-0.5, +0.5], relative to the topmost
-- frame (origin in the center, axis respectively pointing right and up),
-- automatically scaled to occupy all of the surface but without altering the
-- aspect of each individual thing.

-- [FIXME: do I want this?  Things are drawn translated so that their frame origin
-- is their parent center.  I should discuss frames with the others.]
-- Cartesian coordinates always store the position of the object *center*.

-- A rectangle is identified by center x, center y, width and height.
function rectangle_make (x, y, width, height)
   return {["x"] = x,
           ["y"] = y,
           ["width"] = width,
           ["height"] = height}
end

-- Given a rectangle return its top-left and bottom-right Cartesian coordinates,
-- as four results.  The result order is left_x, top_y, right_x, bottom_y .
function rectangle_tl_br (rectangle)
   return rectangle.x - rectangle.width / 2.0,
          rectangle.x + rectangle.width / 2.0,
          rectangle.y + rectangle.height / 2.0,
          rectangle.y - rectangle.height / 2.0
end

-- Is a certain point contained within a given rectangle?  This considers
-- borders as part of the rectangle.
function rectangle_has (rectangle, x, y)
   local left_x, top_y, right_x, bottom_y = rectangle_tl_br (rectangle)
   return x >= left_x and x <= right_x and y <= top_y and y >= bottom_y
end

-- Return a boolean saying whether the two given rectangles have a non-empty
-- intersection.
function rectangle_do_intersect (rectangle1, rectangle2)
   -- This doesn't behave intuitively when rectangle1 is completely embedded
   -- within rectangle2 ; that's why we have to call it twice.
   local rectangle_do_intersect_aux = function (rectangle1, rectangle2)
      local left2, top2, right2, bottom2 = rectangle_tl_br (rectangle2)
      return rectangle_has (rectangle1, left2, top2)
          or rectangle_has (rectangle1, right2, top2)
          or rectangle_has (rectangle1, left2, bottom2)
          or rectangle_has (rectangle1, right2, bottom2)
   end
   -- FIXME: this is broken
   return rectangle_do_intersect_aux (rectangle1, rectangle2)
       or rectangle_do_intersect_aux (rectangle2, rectangle1)
end


-- Things
-- -------------------------------------------------------------

-- A "thing" is any graphical object.  Each thing stores its kind (which is to
-- say, its type in the universe of things), and hierarchical information about
-- its parent and children.

-- Return a fresh thing with the required type.
function thing_make (type)
   return { ["type"] = type,
            ["children"] = set_make_empty (),
            ["depth"] = 0.0 }
end

function thing_has_child (parent, possible_child)
   return set_has (parent, possible_child)
end

function thing_add_child (parent, child)
   set_add (parent.children, child)
   child.parent = parent
end

function thing_remove_child (parent, possible_child)
   if set_has (parent, possible_child) then
      set_remove (parent, possible_child)
      possible_child.parent = nil
   end
end

-- We don't need accessors to get the parent or the children of a thing: simply
-- accessing a field named "parent" or "children" does the trick.

-- Notice that a parent may be nil (that's the case for the root thing), and
-- that children can be an empty set (for every leaf things) -- but empty sets
-- are implemented as empty tables, and *not* nil: it must be safe to iterate
-- over the ipairs of the children of any thing.


-- Return a bounding box, as a rectangle, for the given thing.
function thing_to_bounding_box (thing)
   if thing.type == "node" then
      -- Right now all nodes have a radius.  FIXME: generalize.
      return rectangle_make (thing.x,
                             thing.y,
                             thing.radius * 2,
                             thing.radius * 2)
   elseif thing.type == "edge" then
      local first_x, first_y = thing.first_node.x, thing.first_node.y
      local second_x, second_y = thing.second_node.x, thing.second_node.y
      local width = max (first_x, second_x) - min (first_x, second_x)
      local height = max (first_y, second_y) - min (first_y, second_y)
      local center_x, center_y = average (first_x, second_x), average (first_y, second_y)
      return rectangle_make (center_x, center_y, width, height)
   elseif thing.type == "frame" then
      -- FIXME: this is not correct, but the more I think about this, the more I
      -- convince myself that nested frames aren't needed.
      return rectangle_make (0, 0, 1, 1)
   else
      fatal ("unknown thing type")
   end
end


-- Dictionary
-- -------------------------------------------------------------

-- Some things (currently I don't see the need to make this universal) have a
-- global, unique textual name.

-- The dictionary is a global table mapping each thing's unique textual names to
-- the corresponding thing.  Each named thing also has a "name" field containing
-- its name.
-- There is currently no support for renaming existing things, even if that would
-- be easy to add.

dictionary_the_dictionary = {}

-- Add the given name to the given thing, and return the thing (which allows for
-- chaining).
function dictionary_name (thing, name)
   if dictionary_has (name) then
      error ("the dictionary already has a thing named " .. name)
   end

   thing.name = name
   dictionary_the_dictionary ["name"] = thing
   return thing
end

function dictionary_has (name)
   return dictionary_the_dictionary [name]
end

function dictionary_lookup (name)
   if dictionary_has (name) then
      return dictionary_the_dictionary [name]
   else
      error ("unknown thing name " .. name)
   end
end


-- Depth
-- -------------------------------------------------------------

-- A depth is a number, useful in deciding the order in which two overlapping
-- things are drawn.  In keeping with the intuitive meaning of the word a
-- higher-depth thing is drawn before than a lower-depth thing.

-- The default depth of a thing is zero.  Depths are allowed to be negative.


-- Frames
-- -------------------------------------------------------------

print ("-- Frames")

-- A frame is either the root frame (parent nil) or is contained within another
-- frame.  The center (x, y) position is computed on the fly and not stored.

function frame_make (parent, width, height)
   local res = thing_make ("frame")
   res.parent = parent
   res.width = width
   res.height = height
   res.radius = 0.5
   -- I prefer the root frame not to have a position, to avoid using it by
   -- mistake.  The root frame is drawn behind everything else; other frames
   -- start with the default depth.
   if parent then
      -- Non-root frames are centered by default and keep the default depth.
      res.x = 0.0
      res.y = 0.0
      width = 1.0
      height = 1.0
   else
      -- The topmost frame is the deepest thing.
      res.depth = inf
   end
   return res
end

-- FIXME: do I want these?
function frame_add_child (parent, child)
   thing_add_child (parent, child)
end
function frame_remove_child (parent, child)
   thing_remove_child (parent, child)
end

-- Return the closest ancestor frame of the given thing, or nil if the thing has
-- no ancestor frame.
function thing_closest_ancestor_frame (thing)
   local candidate = thing.parent
   while candidate and candidate.type ~= 'frame' do
      candidate = candidate.parent
   end
   return candidate
end


-- Rendering
-- -------------------------------------------------------------

print ("-- Rendering")

-- A _rendering_ contains an agenda and a coordinate map.

-- The important information contained in an _agenda_ is a sequence of objects
-- to render, keeping the drawing order into account.  In practice the drawing
-- order within a "layer" at the same depth doesn't matter, so the
-- implementation can use a mapping from depth to an (unordered, of course) set
-- of things.
function agenda_make_empty ()
   return {}
end

-- Optional parameters: x, y of the parent.
function render_render_into (thing, agenda, ...)
   local parent_x = ({...}) [1] or 0
   local parent_y = ({...}) [2] or 0

   local x = parent_x + (thing.x or 0)
   local y = parent_y + (thing.y or 0)
   local depth = thing.depth

   print ("Rendering " .. stringize (thing) .. " at (" .. x .. ", " .. y)

   -- FIXME: this idiom is correct but looks terrible.  Isn't there a more
   -- intelligent way of adding a binding to a table if it doesn't exist
   -- within a single expression, and obtaining the value as a result?
   local things_at_depth = agenda [depth] or (set_make_empty ())
   agenda [depth] = things_at_depth

   set_add (things_at_depth, thing)

   for _, child in ipairs (thing.children) do
      render_render_into (child, agenda, x, y)
   end
end

-- A _coordinate map_ is a data structure letting the user find every object at
-- a certain position.  The current implementation should be good enough for our
-- purposes: it's a map, sorted by depth (shallowest first) whose keys are
-- irrelevant and whose values are pairs (in the Lua sense: two-element tables
-- with keys 1 and 2) containing a rectangle and a thing.

-- Given a coordinate map and carthesian coordinates, return the shallowest
-- thing in that position.  This always returns something, as the deepest
-- element is the root frame which takes all the space.
function coordinate_map_lookup (coordinate_map, x, y)
   for _, rectangle_and_thing in ipairs (coordinate_map) do
      if rectangle_has (rectangle_and_thing[1], x, y) then
         return rectangle_and_thing[2]
      end
   end
   unreachable ()
end

-- Given a coordinate map and carthesian coordinates, return a table having
-- consecutive 1-based keys and *every* object at the given coordinate as data,
-- ordered by depth, shallowest-first.
function coordinate_map_lookup_all (coordinate_map, x, y)
   local res = {}
   for _, rectangle_and_thing in ipairs (coordinate_map) do
      if rectangle_has (rectangle_and_thing[1], x, y) then
         res[#res + 1] = rectangle_and_thing[2]
      end
   end
   return res
end

-- Given a node thing, return its cartesian coordinates as percentages, suitable
-- to be used in an SVG image, as two results.
function render_node_to_percentage_coordinates (thing)
   return 50 + thing.x * 100,
          50 - thing.y * 100
end

-- Return the coordinate map.
function render_draw (agenda)
   -- Draw each thing in the agenda from the deepest to the shallowest.  [FIXME:
   -- the clean solution for this would be defining an iterator, which isn't
   -- predefined in Lua as far as I can see.  This not-so-clean solution
   -- consists in first "ordering" (in the Lua sense, by rearranging values over
   -- the same key interval) a table of depths and then using the depth table to
   -- access things from the agenda in the appropriate order]
   local depths = {}
   for depth, _ in pairs (agenda) do
      depths [#depths + 1] = depth
   end
   table.sort (depths, function (a, b) return a > b end)
   for _d, depth in ipairs (depths) do
      for _t, thing in ipairs (agenda [depth]) do
         print ("Drawing (at depth " .. depth .. ") the thing " .. stringize (thing))
         if thing.type == "node" then
            local svg_x, svg_y = render_node_to_percentage_coordinates (thing)
            local svg_color = thing.color or "red"
            svg:append("circle")
               :attr("cx", svg_x .. "%")
               :attr("cy", svg_y .. "%")
               -- FIXME: "%" is wrong for the radius.  What unit should it be?
               :attr("r", (thing.radius * 100) .. "%")
               :attr("fill", svg_color)
         elseif thing.type == "edge" then
            local x1, y1 = render_node_to_percentage_coordinates (thing.first_node)
            local x2, y2 = render_node_to_percentage_coordinates (thing.second_node)
            -- We have to attach the arrow point to second_node's edge, not to its center.
            local center_hdistance = x2 - x1
            local center_vdistance = y2 - y1
            local center_distance = math.sqrt (square (center_hdistance)
                                               + square (center_vdistance))
            local distance_to_second_edge = center_distance
               - thing.second_node.radius * 100 -- FIXME: what is the radius unit?
                                                -- How to make it reasonable?
            --local distance_to_second_edge2 = square (distance_to_second_edge)
            local sine = center_vdistance / center_distance
            local cosine = center_hdistance / center_distance
            x2 = x1 + cosine * distance_to_second_edge
            y2 = y1 + sine * distance_to_second_edge
            svg:append("line")
               :attr("x1", x1 .. "%"):attr("y1", y1 .. "%")
               :attr("x2", x2 .. "%"):attr("y2", y2 .. "%")
               :attr("stroke", "black")
               :attr("stroke-width", "2")
               :attr("marker-end", "url(#arrow-head)")
         elseif thing.type == "frame" then
            print "* (not) drawing a frame"
         else
            warn ("(not) drawing a " .. thing.type)
         end
      end
   end

   -- Now build the coordinate map.  We use the same logic but this time we sort
   -- things the opposite way, from the shallowest to the deepest.
   local coordinate_map = {}
   table.sort (depths, function (a, b) return a < b end) -- FIXME: possibly optimize away
   for _d, depth in ipairs (depths) do
      for _t, thing in ipairs (agenda [depth]) do
         coordinate_map [#coordinate_map + 1] = {thing_to_bounding_box (thing), thing}
      end
   end
   return coordinate_map
end


-- Scratch: clear the graph
-- -------------------------------------------------------------

function svg_clear ()
   svg:selectAll("rect"):remove()
   svg:selectAll("text"):remove()
   svg:selectAll("circle"):remove()
end


-- Scratch
-- -------------------------------------------------------------

root_frame = frame_make (nil, 1.0, 1.0)
node_a = thing_make ("node")
node_a.x = -0.3
node_a.y = -0.2
node_a.radius = 0.01
node_a.depth = -1000
node_a.color = "purple"
thing_add_child (root_frame, node_a)

node_b = thing_make ("node")
node_b.x = 0.1
node_b.y = -0.2
node_b.radius = 0.04
thing_add_child (root_frame, node_b)
node_b.color = "yellow"
node_b.depth = 3

node_c = thing_make ("node")
node_c.x = 0.3
node_c.y = 0.3
node_c.radius = 0.012
thing_add_child (root_frame, node_c)
node_c.depth = -5

edge_ab = thing_make ("edge")
edge_ab.first_node = node_a
edge_ab.second_node = node_b
thing_add_child (root_frame, edge_ab)

node_d = thing_make ("node")
node_d.x = -0.25
node_d.y = -0.4--0.5
node_d.radius = 0.25
node_d.depth = 100
node_d.color = "lightgreen"
thing_add_child (root_frame, node_d)

node_e = thing_make ("node")
node_e.x = 0.25
node_e.y = 0.4--0.5
node_e.radius = 0.25
node_e.depth = 100
node_e.color = "blue"
thing_add_child (root_frame, node_e)

edge_de = thing_make ("edge")
edge_de.first_node = node_d
edge_de.second_node = node_e
edge_de.depth = 100
thing_add_child (root_frame, edge_de)


s = {10, 20, 30}
set_remove (s, 40)
dump (s)

t = thing_make ("foo")
dump (t)

the_agenda = agenda_make_empty ()
render_render_into (root_frame, the_agenda)

-- svg_clear ()

print ("-- Still alive at the end")

dump (the_agenda)

cm = render_draw (the_agenda)

print ("The coordinate map is", stringize (cm))

t = coordinate_map_lookup (cm, -0.29999, -0.20001)
print ("The pointed thing is ", stringize (t))
print ("The pointed thing color is ", t.color)

ts = coordinate_map_lookup_all (cm, -0.29999, -0.20001)
for _, t in pairs (ts) do
   print ("- The pointed thing is ", stringize (t))
   print ("- The pointed thing type is ", t.type)
end


print ("-- Foo")
-- print (time_now () - time_now ())

-- svg:append("circle")
--    :attr("cx", 35 .. "%")
--    :attr("cy", 50  .. "%")
--    :attr("r", 3 .. "%")
--    :attr("fill", "red")
--svg_clear ()

print ("-- Still alive at the end")

r1 = thing_to_bounding_box (node_a)
r2 = thing_to_bounding_box (node_d)
print (rectangle_do_intersect (r1, r1))
