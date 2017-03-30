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

function precondition (condition)
   if not condition then
      fatal ("precondition failed");
   end
end


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


-- Pseudorandom number generation in a useful range.
-- -------------------------------------------------------------

math.randomseed (os.time ())

-- Return a valid coordinate in our range [-1/2, 1/2].
function random_coordinate ()
   local randomin0_1 = math.random ()
   return randomin0_1 - 0.5
end

-- Return a valid coordinate in our range, but not too close to the edge.
function random_coordinate_nice ()
   return random_coordinate () * 0.8
end
