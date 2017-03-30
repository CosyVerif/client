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

-- Update the given layeredata model to contain the given specialization table.
function set_specialization_table (model, specialization_table)
   model.specialization_table = specialization_table
end


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

-- This is mostly for debugging and playing with layeredata, but I think we
-- should keep it around.

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
