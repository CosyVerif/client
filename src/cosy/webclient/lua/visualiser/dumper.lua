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
   assert (already_dumped)
   assert (already_dumped_indices)

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
