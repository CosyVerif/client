package = "cosy-client-dev"
version = "master-1"
source  = {
  url = "git://github.com/saucisson/cosy-client",
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
  "argparse",
  "ansicolors",
  "busted",
  "cluacov",
  "etlua",
  "luacheck",
  "luacov",
  "luacov-coveralls",
  "luafilesystem",
}

build = {
  type    = "builtin",
  modules = {
    ["cosy.client.check.cli"] = "src/cosy/client/check/cli.lua",
  },
  install = {
    bin = {
      ["cosy-check-client" ] = "src/cosy/client/check/bin.lua",
    },
  },
}
