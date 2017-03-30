<?php
   $target_dir = "/tmp/uploaded-models"; // This should not need shell quoting, to play it safe.
   $how_many_files_to_keep = 20;
   $maximum_allowed_size_in_bytes = 1 * 1024 * 1024;

   /* Only keep the $how_many_files_to_keep most recent files on the server; delete
      anything older.  FIXME: this command line probably only works on GNU systems. */
   system ("\\ls -1sdfsdf --quote-name --sort=time --reverse \"{$target_dir}\"/* | \\head --lines=-{$how_many_files_to_keep} | \\xargs \\rm");

  /* Set $uploaded_model to the uploaded Lua model file name (as a Lua module
     which is to say without a directory or a ".lua" extension), or NIL .
     If $uploaded_model ends up non-NIL, then $uploaded_model_pathname is
     also set, to the full pathname of the copied model, included its
     directory and extension. */
  if ($_FILES["uploaded_model"])
  {
    $size = $_FILES["uploaded_model"]["size"];
    if ($size > $maximum_allowed_size_in_bytes)
      $uploaded_model = NIL;
    else
    {
      $random_suffix
        = substr(md5(rand()), 0, 10) . substr(md5(rand()), 0, 10);
      mkdir ($target_dir);
      $target_file = "model_" . $random_suffix;
      $uploaded_model_pathname = $target_dir . "/" . $target_file . ".lua";
      if (move_uploaded_file($_FILES["uploaded_model"]["tmp_name"],
                             $uploaded_model_pathname))
        $uploaded_model = $target_file;
      else
        $uploaded_model = NIL;
    }
  }

  /* If no model was supplied then use the default one, and set
     $uploaded_model_pathname to the example pathname on the server.
     This may be somewhat fragile. */
  if (! $uploaded_model || $uploaded_model == NIL)
  {
    $uploaded_model = "example_model";
    $uploaded_model_pathname = getcwd () . "/lua/example_model.lua";
  }
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
  <head>
    <title><?php echo "CosyVerif web interface: {$uploaded_model}"; ?></title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
    <link rel="icon" type="image/png" href="favicon.png"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script type="text/javascript" src="js/d3/d3.js"></script>
    <script src="js/lua.vm/lua.vm.js"></script>
  </head>
  <body>
    <h1 style="text-size: -4;">Lua scratch</h1>
    <div id="svg-container"
           style="/*width: 100%;*/">
       <svg id="svg-graph"
            preserveAspectRatio="xMidYMid meet"
            viewBox="0 0 100 100"
            style="/*height: auto;
                   width: 50%;*/"
            version="1.1"></svg>
    </div>
    <script type="text/lua" lang="Lua">
      -- Taken from lua.vm.js:
      local function load_lua_over_http (url)
        local xhr = _G.js.new (_G.window.XMLHttpRequest)
        xhr:open ("GET", url, false)
        local ok, err = pcall (xhr.send, xhr)
        if not ok then
          return nil, tostring (err)
        elseif xhr.status ~= 200 then
          return nil, "HTTP GET " .. xhr.statusText .. ": " .. url
        end
        return load (xhr.responseText, url, "t")
      end
      package.searchers [#package.searchers] = nil
      package.searchers [#package.searchers] = nil
      table.insert (package.searchers, function (mod_name)
    --    print ("* Searching for " .. mod_name)
        if not mod_name:match "/" then
          local full_url = "/lua/" .. mod_name
          local func, err = load_lua_over_http (full_url)
          if func ~= nil then return func end
          return "\n    " .. err
        end
      end)
      -- Use PHP to output a (Lua) string containing the uploaded model
      -- name as a module.  It's simpler to have a Lua variable uploaded_model_name
      -- with the same value as the PHP variable $uploaded_model .
      uploaded_model_name = <?php echo "\"{$uploaded_model}\"\n"; ?>
      print ("The uploaded model is " .. uploaded_model_name)
      --the_model = require (uploaded_model_name)
      require 'visualiser'
    </script>
    <form name="my_form"
          enctype="multipart/form-data"
          action="/cosy/webclient/index.php"
          method="post">
      <input type="file" name="uploaded_model"/>
      <input type="hidden" name="MAX_FILE_SIZE" value="1024"/>
      <input type="submit" value="Upload"/>

      <!-- <input id="upload_button" type="file" value="Upload"/> -->
    </form>
  <hr/>
<h3>Model source</h3>
  <?php
  print ("<!-- uploaded_model_pathname is {$uploaded_model_pathname} -->\n");
  $model_text = file_get_contents($uploaded_model_pathname);
  if ($model_text === FALSE)
    print ("<i>Could not read the model source file at
               <tt>{$uploaded_model_pathname}</tt> on the server.</i>");
  else
  {
    print ("<pre>");
    print (htmlspecialchars($model_text));
    print ("</pre>\n");
  }
?>
  <hr/>
  </body>
</html>
