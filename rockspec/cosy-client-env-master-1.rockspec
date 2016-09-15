package = "cosy-client-env"
version = "master-1"
source  = {
  url    = "git+https://github.com/cosyverif/client.git",
  branch = "master",
}

description = {
  summary    = "CosyVerif: client (dev dependencies)",
  detailed   = [[
    Development dependencies for cosy-client.
  ]],
  homepage   = "http://www.cosyverif.org/",
  license    = "MIT/X11",
  maintainer = "Alban Linard <alban@linard.fr>",
}

dependencies = {
  "lua >= 5.1",
  "busted",
  "cluacov",
  -- "hashids",
  "jwt",
  "luacheck",
  "luacov",
  "luacov-coveralls",
}

build = {
  type    = "builtin",
  modules = {},
}
