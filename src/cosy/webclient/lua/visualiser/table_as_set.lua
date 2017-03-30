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
