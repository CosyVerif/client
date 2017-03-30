-- Indeed, this is -*- Lua -*-

-- Load modules.
-- -------------------------------------------------------------

require "utility"
require "table_as_set"
require "dumper"

-- The global Layer is used in every model.
Layer = require "layeredata" -- FIXME: no, I don't want this

require "layeredata_visit"

-- Load the layeredata model supplied by the user.
my_model = require (uploaded_model_name)


-- Core machinery
-- -------------------------------------------------------------

-- Return a zero-argument function, itself returning a fresh identifier at every
-- call.
function counter_generator ()
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
object_counter = counter_generator ()


-- D3 wrapper
-- -------------------------------------------------------------

-- We simply provide a global lua object called d3 wrapping what is known as d3
-- in JavaScript.  Thru this object we can just use the JavaScript API in Lua.
d3 = js.global:eval('d3')

-- Temporary globals, for me to test.
--svg_width="30%"
--svg_height="100%"
svg_background="cyan"

-- Our picture is an SVG object, already present in the initial HTML file but empty.
-- We recognize it by its id and its parent's.
svg = d3:select("body"):select("#svg-container"):select("#svg-graph")
      --:attr("width", svg_width)--:attr("height", svg_height)

-- This will be useful later.  The important information is simply the "refX" attribute name.
-- http://stackoverflow.com/questions/16660193/get-arrowheads-to-point-at-outer-edge-of-node-in-d3

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


-- SVG handling
-- -------------------------------------------------------------

-- SVGs can have no background color, as far as I see.  But the workaround is
-- easy: the bottom object drawn in the SVG will be a rectangle, taking all the
-- space.  This needs to be the first object to be drawn.
function add_svg_background ()
   svg:append("rect"):attr("width", "100%")
      :attr("height", "100%"):attr("fill", svg_background)
end

-- Remove every element we use from the SVG DOM, except the background.
function svg_clear ()
   svg:selectAll("rect"):remove()
   svg:selectAll("text"):remove()
   svg:selectAll("circle"):remove()
   svg:selectAll("line"):remove()

   -- By removing all rect's we destroyed the SVG background as well.  Re-add it.
   add_svg_background ()
end

-- Coordinates
-- -------------------------------------------------------------

-- Cartesian coordinates are numbers in [-0.5, +0.5], relative to the topmost
-- frame (origin in the center, axis respectively pointing right and up),
-- automatically scaled to occupy all of the surface but without altering the
-- aspect of each individual thing.
-- [FIXME: do I want this?  Things are drawn translated so that their frame origin
-- is their parent center.  I should discuss frames with the others.  [Fabrice
--  and Laure agree: from now on there is only one frame, at the top.]]
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
   -- FIXME: this is broken.  https://silentmatt.com/rectangle-intersection/
   -- What am I doing wrong?
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


-- The frame
-- -------------------------------------------------------------

-- The frame only serves to contain the actually visible things to be drawn.
-- Each picture is supposed to have exactly one frame, at the top of its
-- hierarchy.
-- A frame always has nil as its parent and takes up all the available space.
function frame_make ()
   local res = thing_make ("frame")
   res.parent = nil
   res.width = 1
   res.height = 1
   res.radius = 0.5
   res.x = 0.0
   res.y = 0.0
   res.depth = inf -- Conceputally clean, but not really used for the frame.
   return res
end

-- Update the given thing, making it a parent of the other given thing.
function frame_add_child (parent, child)
   thing_add_child (parent, child)
end

-- Update the given thing so that it is no longer a parent of the other given
-- thing.
function frame_remove_child (parent, child)
   thing_remove_child (parent, child)
end

-- Return the closest ancestor frame of the given thing, or nil if the thing has
-- no ancestor frame.  FIXME: do I want this?
function thing_closest_ancestor_frame (thing)
   local candidate = thing.parent
   while candidate and candidate.type ~= 'frame' do
      candidate = candidate.parent
   end
   return candidate
end


-- Rendering
-- -------------------------------------------------------------

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

   print ("depth: ", thing.depth, "type: ", thing.type)

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
   -- Clear the previous SVG image, if any.
   svg_clear ()

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
         --print ("Drawing (at depth " .. depth .. ") the thing " .. stringize (thing))
         if thing.type == "frame" then
            -- Do nothing: we don't draw the root frame.
         elseif thing.type == "node" then
            local svg_x, svg_y = render_node_to_percentage_coordinates (thing)
            local svg_color = thing.color
            local svg_shape = 'circle'--thing.shape
            svg:append(svg_shape)
               :attr("cx", svg_x .. "%")
               :attr("cy", svg_y .. "%")
               :attr("r", (thing.radius * 100) .. "%") -- FIXME: this assumes that the aspect is 1.
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
               - thing.second_node.radius * 100 -- This assumes that the aspect is 1.
            --local distance_to_second_edge2 = square (distance_to_second_edge)
            local sine = center_vdistance / center_distance
            local cosine = center_hdistance / center_distance
            x2 = x1 + cosine * distance_to_second_edge
            y2 = y1 + sine * distance_to_second_edge
            svg:append("line")
               :attr("x1", x1 .. "%"):attr("y1", y1 .. "%")
               :attr("x2", x2 .. "%"):attr("y2", y2 .. "%")
               :attr("stroke", "black")
               :attr("stroke-width", "0.5")
               :attr("marker-end", "url(#arrow-head)")
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


-- Demo
-- -------------------------------------------------------------

print "Making things from the example..."
root_frame = frame_make ()
-- -- Destructively update the given layeredata node, adding coordinates
-- -- for missing fields where needed.  It is safe to do this on entities
-- -- without concern for default values, since these values are strictly
-- -- per-entity.
-- for name, _ in Layer.pairs (my_model.vertices) do
--    local vertex_entity = vertex_as_entity (my_model, name)
--    for _, field_name in pairs ({ 'x', 'y' }) do
--       print ("(before) field_name", field_name)
--       local value = vertex_attribute (my_model, name, field_name)
--       print ("(after) field_name", field_name)
--       if value == nil or value == -1 then
--          vertex_entity [field_name] = random_coordinate_nice ()
--       end
--    end
--    for _, field_name in pairs ({ 'depth' }) do
--       vertex_entity [field_name] = vertex_attribute (my_model, name, field_name) or 0
--    end
--    for _, field_name in pairs ({ 'radius' }) do
--       print ("field_name", field_name)
--       vertex_entity [field_name] = vertex_attribute (my_model, name, field_name) or 0.025
--    end
-- --   vertex_entity.x = vertex_entity.x or random_coordinate_nice ()
-- --   vertex_entity.y = vertex_entity.y or random_coordinate_nice ()
--    vertex_entity.depth = vertex_entity.depth or 0
--    vertex_entity.radius = vertex_entity.radius or 0.025
-- end

-- -- Visit the model as a graph.
-- local id_to_vertex_thing = {}
-- for id, vertex in Layer.pairs (my_model.vertices) do
--    local thing = thing_make ("node")

--    -- FIXME: use my thing dictionary instead of this ad-hockery.
--    id_to_vertex_thing [id] = thing
--    thing.id = id -- not in my structure; FIXME: use the thing dictionary

--    -- Copy fields from the entity to my thing.
--    for _, field_name in pairs ({ 'x', 'y', 'depth', 'radius', 'color' }) do
--       --print ("The id is ", id , " the field is ", field_name, " the value is ", vertex[field_name])
--       print ("vertex_attribute", vertex_attribute)
--       --print ("QQ: ", vertex_attribute (my_model, id, field_name))
--       thing [field_name] = vertex_attribute (my_model, id, field_name)
--       --thing [field_name] = vertex [field_name]
--    end
--    thing_add_child (root_frame, thing)
-- end

-- for id, edge in Layer.pairs (my_model.edges) do
--    print ("id: ", id, "edge:", edge)
--    print (edge.source)

--    -- Make an edge thing.
--    local thing = thing_make ("edge")

--    -- Find its two endpoints, that we must have already met.  Fail
--    -- if we don't know their names.
--    local source_id, target_id = entity_name (my_model, edge.source), entity_name (my_model, edge.target)
--    assert (id_to_vertex_thing [source_id])
--    assert (id_to_vertex_thing [target_id])
--    thing.first_node = id_to_vertex_thing [source_id]
--    thing.second_node = id_to_vertex_thing [target_id]

--    -- Arrows should never be drawn over anything else.
--    thing.depth = inf

--    -- Add the thing.
--    thing_add_child (root_frame, thing)
-- end

-- -- Render.
-- print "Rendering..."
-- the_agenda = agenda_make_empty ()
-- render_render_into (root_frame, the_agenda)
-- the_coordinate_map = render_draw (the_agenda)
-- print "...done."

-- --[[
-- for id, vertex in Layer.pairs (my_model.vertices) do
--    print ("The vertex " .. id .. " (actually " .. stringize (vertex) .. ") has color " .. stringize (vertex.color))
--    if is_graph_element_name_entity_name (my_model, id, 'vertices', 'places') then
--       print ("The vertex " .. id, vertex, " is a place")
--    end
--    if is_graph_element_name_entity_name (my_model, id, 'vertices', 'transitions') then
--       print ("The vertex " .. id, vertex, " is a transition")
--    end
-- end

-- for id, q in Layer.pairs (my_model.places) do
--    print ("The place " .. id .. " (actually " .. stringize (q) .. ") has color " .. stringize (q.color))
-- end
-- for id, q in Layer.pairs (my_model.transitions) do
--    print ("The transition " .. id .. " (actually " .. stringize (q) .. ") has color " .. stringize (q.color))
-- end
-- --[[
-- for id, q in Layer.pairs (my_model.edges) do
--    assert (is_edge_layeredata_transition (my_model, id))
--    print ("The edge " .. id .. " (actually " .. stringize (q) .. ") is an edge")
-- end
-- --]]

-- --[[
-- for id, edge in Layer.pairs (my_model.edges) do
--    -- They all print false here, which is correct.
--    print ("edge", id, edge, "place <= _:" .. tostring (my_model[meta].place_type <= edge))
--    print ("edge", id, edge, "transition <= _:" .. tostring (my_model[meta].transition_type <= edge))
--    print ("edge", id, edge, "_ <= place:" .. tostring (edge <= example[meta].place_type))
--    print ("edge", id, edge, "_ <= transition:" .. tostring (edge <= example[meta].transition_type))
-- end
-- --]]

-- print ("Places: " .. stringize (my_model.places))
-- print ("Transitions: " .. stringize (my_model.transitions))
-- dump (my_model)
-- dump (ref)

print ("===================================================")

-- -- Visit the model as a graph.
-- id_to_vertex_thing = {}
-- for id, vertex in Layer.pairs (my_model.vertices) do
--    local thing = thing_make ("node")

--    -- FIXME: use my thing dictionary instead of this ad-hockery.
--    id_to_vertex_thing [id] = thing
--    --thing.id = id -- not in my structure; FIXME: use the thing dictionary

--    -- Copy fields from the entity to my thing.
--    for _, field_name in pairs ({ 'x', 'y', 'depth', 'radius', 'color' }) do
--       print (id, field_name, vertex_attribute (my_model, id, field_name))
--    end
-- end

for id, vertex in Layer.pairs (my_model.vertices) do
   for _, field_name in pairs ({ 'x', 'y', 'depth', 'radius', 'color' }) do
      print (id, field_name, ":")
      print (--id, field_name,
             "", vertex_attribute (my_model, id, field_name))
   end
end
