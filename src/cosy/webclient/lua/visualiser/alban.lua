require "dumper"

--local
   Layer = require "layeredata"

local defaults = Layer.key.defaults
local meta     = Layer.key.meta
local refines  = Layer.key.refines

local record     = Layer.new { name = "data.record" }
local collection = Layer.new { name = "data.collection" }

collection [meta] = {
  [collection] = {
    key_type        = false,
    value_type      = false,
    key_container   = false,
    value_container = false,
    minimum         = false,
    maximum         = false,
  },
}
collection [defaults] = {
  Layer.reference (collection) [meta] [collection].value_type,
}

local graph = Layer.new { name = "graph" }

graph [refines] = {
  record,
}

graph [meta] = {}

-- Vertices are empty in base graph.
graph [meta].vertex_type = {
  [refines] = {
    record,
  }
}

-- Arrows are records with only one predefined field: `vertex`.
-- It points to the destination of the arrow, that must be a vertex of the
-- graph.
-- Edges have no label in base graph.
-- They only contain zero to several arrows. The arrow type is defined for
-- each edge type.
-- The `default` key states that all elements within the `arrows` container
-- are of type `arrow_type`.
graph [meta].edge_type = {
  [refines] = {
    record,
  },
  [meta] = {
    arrow_type = {
      [refines] = {
        record,
      },
      [meta] = {
        [record] = {
          vertex = {
            value_type      = Layer.reference (graph) [meta].vertex_type,
            value_container = Layer.reference (graph).vertices,
          }
        }
      },
      vertex = nil,
    },
  },
}

graph [meta].edge_type.arrows = {
  [refines] = {
    collection,
  },
  [meta] = {
    [collection] = {
      value_type = Layer.reference (graph [meta].edge_type) [meta].arrow_type,
    }
  },
}

-- A graph contains a collection of vertices.
-- The `default` key states that all elements within the `vertices` container
-- are of type `vertex_type`.
graph.vertices = {
  [refines] = {
    collection,
  },
  [meta] = {
    [collection] = {
      value_type = Layer.reference (graph) [meta].vertex_type,
    },
  },
}

-- A graph contains a collection of edges.
-- The `default` key states that all elements within the `edges` container
-- are of type `edge_type`.
graph.edges = {
  [refines] = {
    collection,
  },
  [meta] = {
    [collection] = {
      value_type = Layer.reference (graph) [meta].edge_type,
    },
  },
}

local binary_edges = Layer.new { name = "graph.binary_edges" }

binary_edges [refines] = {
  graph
}

binary_edges [meta].edge_type.arrows [meta] = {
  [collection] = {
    minimum = 2,
    maximum = 2,
  },
}

local directed = Layer.new { name = "graph.directed" }

directed [refines] = {
  graph,
  binary_edges,
}

directed [meta].edge_type [meta] [record] = {
  source = {
    value_container = Layer.reference (directed).vertices,
  },
  target = {
    value_container = Layer.reference (directed).vertices,
  },
}

directed [meta].edge_type.arrows = {
  source = {
    vertex = Layer.reference (directed [meta].edge_type).source,
  },
  target = {
    vertex = Layer.reference (directed [meta].edge_type).target,
  },
}

local petrinet = Layer.new { name = "petrinet" }

petrinet [refines] = {
  directed,
}

petrinet [meta].place_type = {
  [refines] = {
    Layer.reference (petrinet) [meta].vertex_type,
  },
  [meta] = {
    [record] = {
      identifier = false,
      marking    = false,
    }
  }
}

petrinet [meta].transition_type = {
  [refines] = {
    Layer.reference (petrinet) [meta].vertex_type,
  },
  -- Note for Alban: this meta field was added by Luca, just to have some place
  -- where to store default non-overridden attributes.
  [meta] = {
  }
}

petrinet [meta].arc_type = {
  [refines] = {
    Layer.reference (petrinet) [meta].edge_type,
  },
}

petrinet.places = {
  [refines] = {
    collection,
  },
  [meta] = {
    [collection] = {
      value_type = Layer.reference (petrinet) [meta].place_type,
    }
  },
}

petrinet.transitions = {
  [refines] = {
    collection,
  },
  [meta] = {
    [collection] = {
      value_type = Layer.reference (petrinet) [meta].transition_type,
    }
  },
}

petrinet [meta].pre_arc_type = {
  [refines] = {
    Layer.reference (petrinet) [meta].arc_type,
  },
  [meta] = {
    [record] = {
      source = {
        value_container = Layer.reference (petrinet).places,
      },
      target = {
        value_container = Layer.reference (petrinet).transitions,
      },
    },
  },
}

petrinet [meta].post_arc_type = {
  [refines] = {
    Layer.reference (petrinet) [meta].arc_type,
  },
  [meta] = {
    [record] = {
      source = {
        value_container = Layer.reference (petrinet).transitions,
      },
      target = {
        value_container = Layer.reference (petrinet).places,
      },
    },
  },
}

petrinet.pre_arcs = {
  [refines] = {
    collection,
  },
  [meta] = {
    [collection] = {
      value_type = Layer.reference (petrinet) [meta].pre_arc_type,
    }
  },
}

petrinet.post_arcs = {
  [refines] = {
    collection,
  },
  [meta] = {
    [collection] = {
      value_type = Layer.reference (petrinet) [meta].post_arc_type,
    }
  },
}

petrinet.arcs = {
  [refines] = {
    Layer.reference (petrinet).pre_arcs,
    Layer.reference (petrinet).post_arcs,
  },
}

petrinet.vertices [refines] = {
  Layer.reference (petrinet).places,
  Layer.reference (petrinet).transitions,
}
petrinet.edges    [refines] = {
  Layer.reference (petrinet).arcs,
}

-- Tentative: begin
petrinet[meta].place_type[meta].color = 'default for places, not overridden'
petrinet[meta].transition_type[meta].color = 'default for transitions, not overridden'
petrinet[meta].pre_arc_type[meta].color = 'default for pre-arcs, not overridden'
petrinet[meta].post_arc_type[meta].color = 'default for post-arcs, not overridden'

petrinet[meta].place_type[meta].depth = 1 / 0
petrinet[meta].transition_type[meta].depth = 1 / 0
petrinet[meta].pre_arc_type[meta].depth = 1 / 0
petrinet[meta].post_arc_type[meta].depth = 1 / 0

petrinet[meta].place_type[meta].x = -1
petrinet[meta].place_type[meta].y = -1
petrinet[meta].transition_type[meta].x = -1
petrinet[meta].transition_type[meta].y = -1
petrinet[meta].place_type[meta].shape = 'circle'
petrinet[meta].transition_type[meta].shape = 'rect'
-- Tentative: end

local example, ref = Layer.new { name = "example" }

example [refines] = {
  petrinet,
}
example.places     .a  = {}
example.places     .c  = {}
example.transitions.b  = {}
example.pre_arcs   .ab = {
  source = ref.places.a,
  target = ref.transitions.b,
}
example.post_arcs  .bc = {
   source = ref.transitions.b,
   target = ref.places.c,
}


-- My layeredata reflection facilities
------------------------------------------------------------------------------

-- This function should probably only be called thru wappers (see right below),
-- as it is very error-prone.  It takes:
-- * the layeredata model [FIXME: what should I call it?], for example
--   mypetrinet (and *not* 'mypetrinet' as a string);
-- * the id of an object whose layeredata entity we want to check (for example
---  'a');
-- * the name of the graph element in plural form (for example, 'vertices');
-- * the name of the layeredata entity in plural form (for example, 'places').
-- The function returns a boolean, true iff the named object, which has to be of
-- the specified graph element kind, is of the right layeredata entity.
function is_graph_element_name_entity_name (model, object_name,
                                            graph_elements_name, entities_name)
   -- Sanity checks: ensure that the model exists and is not just a model name,
   -- and that the object is of the right graph element kind.
   assert (type (model) ~= 'string')
   assert (type (model) ~= 'nil')
   assert (model [graph_elements_name] [object_name] ~= nil)
   -- Return true iff the object exists among the specified layeredata entities,
   -- and inherits from such an entity.  The second condition might not be
   -- strictly needed, but this system is very error-prone so I want to be sure.
   return      model [entities_name] [object_name] ~= nil
          and (model [entities_name] [object_name]
                  <= model [graph_elements_name] [object_name])
end

--[[
-- Convenient wrappers around is_graph_element_name_entity_name: return true iff
-- the given object name is respectively a place, a transition, or an edge
-- within the given model.
-- FIXME: this is only for Petri Nets!
-- [FIXME: I should probably call "models" something else].
function is_vertex_layeredata_place (model, name)
   return is_graph_element_name_entity_name (model, name, 'vertices', 'places')
end
function is_vertex_layeredata_transition (model, name)
   return is_graph_element_name_entity_name (model, name, 'vertices', 'transitions')
end
--]]

-- Given a model [FIXME: call it something else?], and object name, a plural
-- graph elements name and a plural entities name, return the named object as
-- an entity.
-- Just like is_graph_element_name_entity_name , this function is very
-- inconvenient to use directly and should probably always be called thru
-- wrappers.
function graph_element_name_to_entity (model, object_name,
                                       graph_elements_name, entities_name)
   -- Make sure the object we are speaking about is actually of the right entity.
   assert (is_graph_element_name_entity_name (model, object_name,
                                              graph_elements_name,
                                              entities_name))
   return model [entities_name] [object_name]
end

--[[
-- Wrappers for graph_element_name_to_entity.
-- FIXME: this is only for Petri Nets!
-- [FIXME: I should probably call "models" something else].
function vertex_name_to_place (model, object_name)
   return graph_element_name_to_entity (model, object_name, 'vertices', 'places')
end
function vertex_name_to_transition (model, object_name)
   return graph_element_name_to_entity (model, object_name, 'vertices', 'transitions')
end
--]]

-- Given an entity, return its name.  In the end I found this revoltingly ugly
-- way to do it, and it is unfortunately needed: edges refer to their endpoints
-- as entities, not as names.  This seems to work but I should really really
-- ask Alban.
function entity_name (model, entity)
   -- Notice that the model is not actually needed; but I anticipate that it will
   -- be a useful parameter in a future, cleaner version.  Let's try and not break
   -- the callers.
   return Layer.hidden [entity].keys [2]
end


-- Specialization tables
------------------------------------------------------------------------------

-- A specialization table maps each plural graph elements name into a list of
-- plural entities names.  For example, since in a Petri Net a vertex can be
-- either a place or a transition, the specialization table for Petri Nets will
-- contain a mapping from 'vertices' to {'places', 'transitions'}.

-- FIXME: can I automatically generate specialization tables by visiting a
-- formalism as a graph?  Almost certainly, but right now I'm building them my
-- hand.

-- The specialization table for Petri Nets.
petrinet_specialization_table
   = {['vertices'] = {'places', 'transitions'},
      ['edges'] = {'pre_arcs', 'post_arcs'}}


-- Add the appropriate specialization table to the example.
example.specialization_table = petrinet_specialization_table


-- Specialization
------------------------------------------------------------------------------

-- This functionality relies on specialization tables being accessible from the
-- model.

-- An inconvenient function, like above.
-- FIXME: comment better.  The idea is automatically finding the right entities
-- name from the graph element_name.
function graph_element_to_entities_name (model, object_name,
                                         graph_elements_name)
   -- Make sure the object actually belongs to the specified graph elements.
   assert (model [graph_elements_name] [object_name] ~= nil)

   -- Look for candidate entities names.  Of course the graph elements name must
   -- belong to the specialization table keys, and the graph elements name must
   -- have at least one associated entities name.
   local entities_names = model.specialization_table [graph_elements_name]
   assert (entities_names ~= nil)
   assert (type (entities_names) == 'table')
   -- print ("type of model.specialization_table: ", type (model.specialization_table))
   -- print ("type of entities_names: ", type (entities_names)) -- table
   -- print ("entities_names: ", entities_names) -- something weird
   -- print ("entities_names stringized: ", stringize (entities_names)) -- "#0{ }" , because of layeredata's OO weirdness
   -- print ("# entities_names", # entities_names) -- This is zero, because of layeredata's OO weirdness
   -- -- assert (# entities_names > 0) -- This fails because of layeredata's OO weirdness

   -- Return the first entities name in the list to which the named object belongs.
   for _, candidate_entities_name in Layer.ipairs (entities_names) do
      -- print ("One of the " .. graph_elements_name .. " might be one of the " .. candidate_entities_name)
      if is_graph_element_name_entity_name (model, object_name,
                                            graph_elements_name, candidate_entities_name) then
         return candidate_entities_name
      end
   end

   -- We haven't find any suitable entity.  This should not happen.
   assert (false)
end

-- Return the object with the given name in the given model, which must belong
-- to the given graph elements, as an entity.
function graph_element_as_entity (model, object_name, graph_elements_name)
   local entities_name = graph_element_to_entities_name (model, object_name,
                                                         graph_elements_name)
   return graph_element_name_to_entity (model, object_name,
                                        graph_elements_name, entities_name)
end

-- Return the value of the named attribute of the named object (which must elong
-- to the given graph elements) in the given model, or the default value if the
-- object has not overridden the default.  If neither an overridden value nor a
-- default exists return nil.
function graph_element_attribute (model, object_name, attribute_name,
                                  graph_elements_name)
   local as_entity = graph_element_as_entity (model, object_name,
                                              graph_elements_name)
   local overridden_attribute = as_entity [attribute_name]
   return    overridden_attribute
          or (    as_entity [meta]
              and as_entity [meta] [attribute_name])
end

-- A simple wrapper around graph_element_attribute , looking up the value of the given
-- attribute for the named edge (or its default value).
function edge_attribute (model, object_name, attribute_name)
   return graph_element_attribute (model, object_name, attribute_name, 'edges')
end

-- Like edge_attribute , but for vertices.
function vertex_attribute (model, object_name, attribute_name)
   return graph_element_attribute (model, object_name, attribute_name, 'vertices')
end


-- Exploration
------------------------------------------------------------------------------

-- Recursively visit the given structure using Layeredata iterators, and print
-- an indented tree.  Each line is preceded by the specified prefix, which is
-- allowed to be the empty string.
function explore (prefix_to_print, whatever)
   -- print ("Exploring ", whatever, ", which has type " .. type (whatever))
   if type (whatever) ~= 'table' then
      print (prefix_to_print .. ':',
             whatever,
             '(type ' .. type (whatever) .. ': ' .. stringize (whatever) .. ')' )
   else
      print (prefix_to_print .. ':')
      for key, value in Layer.pairs (whatever) do
         explore (prefix_to_print .. "/" .. tostring (key), value)
      end
   end
end


-- Scratch
------------------------------------------------------------------------------

print "=========================\n"
example.places.a.color = 'overridden for a'
example.transitions.b.color = 'overridden for b'
example.pre_arcs.ab.color = 'overridden for ab'
--example.places.c.color = 'overridden for c'
print "qqqqqqqqqqqqqqqqqqqqqqqqq\n"
print (vertex_attribute (example, 'c', 'color'))
print (vertex_attribute (example, 'a', 'color'))
print (vertex_attribute (example, 'b', 'color'))
print (vertex_attribute (example, 'c', 'color'))
print (edge_attribute (example, 'ab', 'color'))
print (edge_attribute (example, 'bc', 'color'))

print (vertex_attribute (example, 'a', 'shape'))
print (vertex_attribute (example, 'b', 'shape'))
print (vertex_attribute (example, 'a', 'x'))
print (vertex_attribute (example, 'b', 'x'))
print ("a depth", vertex_attribute (example, 'a', 'depth'))
print ("b depth", vertex_attribute (example, 'b', 'depth'))
print ("c depth", vertex_attribute (example, 'c', 'depth'))
print ("ab depth", edge_attribute (example, 'ab', 'depth'))

print "-------------------------\n"
--print (example.vertices.a)
--explore ("example", example)


--[[
-- Iteration over Petri net arcs:
for id, arc in Layer.pairs (example.arcs) do
  print (id, arc.source, arc.target)
end
--]]

-- Iteration over graph edges:
for id, edge in Layer.pairs (example.edges) do
   print (id, edge.source, edge.target)
   print ("edge.source est ", edge.source, "(stringized " .. stringize (edge.source)
          .. "), named " .. entity_name (example, edge.source))
   print ("edge.target est ", edge.target, "(stringized " .. stringize (edge.target)
          .. "), named " .. entity_name (example, edge.target))
   print (edge)
end

-- Iteration over graph vertices:
for id, vertex in Layer.pairs (example.vertices) do
  print (id, vertex)
end

print "-------------------------\n"

require "utility"
require "table_as_set"
require "dumper"
--require "layeredata_visit"

my_model = example
for id, vertex in Layer.pairs (my_model.vertices) do
   for _, field_name in pairs ({ 'x', 'y', 'depth', 'radius', 'color', 'nonexisting' }) do
      print (id, field_name, stringize (vertex_attribute (my_model, id, field_name)))
   end
end
