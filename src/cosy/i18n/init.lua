local Layer    = require "layeredata"
local Lustache = require "lustache"
local Plural   = require "i18n.plural"

local Metatable = {}

local I18n      = setmetatable ({}, Metatable)
I18n.__index    = I18n

local Message   = {}
Message.__index = Message

local Hidden    = setmetatable ({}, { __mode = "k" })

function I18n.new (options)
  options = options or {}
  local i18n = setmetatable ({}, I18n)
  Hidden [i18n] = {
    locale       = options.locale or os.getenv "LANG",
    translations = {},
    index        = Layer.new {},
  }
  Hidden [i18n].index [Layer.key.refines] = Hidden [i18n].translations
  return i18n
end

function I18n.__add (i18n, translations)
  assert (getmetatable (i18n) == I18n)
  assert (type (translations) == "table")
  local t = {}
  local sources = Hidden [i18n].translations
  for i = 1, #sources do
    t [i] = sources [i]
  end
  t [#t+1] = Layer.new {
    data = translations,
  }
  local result = setmetatable ({}, I18n)
  Hidden [result] = {
    locale       = Hidden [i18n].locale,
    translations = t,
    index        = Layer.new {},
  }
  Hidden [result].index [Layer.key.refines] = Hidden [result].translations
  return result
end

function I18n.__div (i18n, key)
  assert (getmetatable (i18n) == I18n)
  return Hidden [i18n].index [key] ~= nil
end

function I18n.__index (i18n, key)
  assert (getmetatable (i18n) == I18n)
  local entry = Hidden [i18n].index [key]
  assert (entry, key)
  return setmetatable ({
    i18n        = i18n,
    key         = key,
    translation = entry,
  }, Message)
end

function Metatable.__call (_, data, locale)
  locale = type (data) == "table" and data.locale or locale or "en"
  local function translate (t)
    if type (t) ~= "table" then
      return t
    end
    for _, v in pairs (t) do
      if type (v) == "table" and not getmetatable (v) then
        translate (v)
      end
    end
    if t._ then
      local _locale = t.locale
      t.locale  = t.locale or locale
      t.message = t._ % t
      t._       = t._.key
      t.locale  = _locale
    end
    return t
  end
  return translate (data)
end

function Message.__mod (message, context)
  local locale = context.locale or "en"
  locale = locale:lower ()
  locale = locale:gsub ("_", "-")
  locale = locale:match "^(%w%w-%w%w)" or locale:match "^(%w%w)"
  if not message.translation [locale] then
    locale = locale:match "^(%w%w)"
  end
  if not message.translation [locale] then
    locale = "en"
  end
  assert (message.translation [locale])
  local result = message.translation [locale] or message.key
  local t      = {}
  for k, v in pairs (context) do
    t [k] = v
    if type (v) == "number" then
      assert (context ["~" .. k] == nil)
      t [k .. "~" .. Plural.get (locale, v)] = true
    end
  end
  return Lustache:render (result, t)
end

return I18n
