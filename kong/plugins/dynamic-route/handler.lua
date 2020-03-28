-- If you're not sure your plugin is executing, uncomment the line below and restart Kong
-- then it will throw an error which indicates the plugin is being loaded at least.
-- assert(ngx.get_phase() == "timer", "Request Validator CE coming to an end!")

-- Grab pluginname from module name
local plugin_name = ({...})[1]:match("^kong%.plugins%.([^%.]+)")

-- load the base plugin object and create a subclass
local plugin = require("kong.plugins.base_plugin"):extend()

local socket = require("socket")
local util = require("kong.plugins.dynamic-route.string_util")

-- constructor
function plugin:new()
  plugin.super.new(self, plugin_name)
end

function tableContains(table, element, case_sensitive)
  if nil == element then
    return false
  end
  local x = element
  if nil ~= case_sensitive and not case_sensitive then
    x = element:lower()
  end
  for _, value in pairs(table) do
    if nil ~= case_sensitive and not case_sensitive then
      if value:lower() == x then
        return true
      end
    else
      if value == x then
        return true
      end
    end
  end
  return false
end

function getCfgList(config, request, path) 
  local urlCfg = config.exact_match and config.exact_match[path]
  if nil ~= urlCfg and type(urlCfg) == "table" then
    -- if the method is GET, then we try "GET" and "*"
    local cfgList = urlCfg[request.get_method()] or urlCfg["*"]
    if nil ~= cfgList then return cfgList end
  end
  
  if config.pattern_match and type(config.pattern_match) == "table" then
    for pattern, urlCfg in pairs(config.pattern_match) do
      if string.match(path, pattern) then
        local cfgList = urlCfg[request.get_method()] or urlCfg["*"]
        if nil ~= cfgList then return cfgList end
      end
    end
  end

  return nil
end

function plugin:access(config)
  plugin.super.access(self)

  local debug = config.debug

  -- get per url config object, does not include querystring according to Kong doc
  local path = kong.request.get_path()

  if nil ~= path then
    path = string.gsub(path, "//", "/")
  end

  local cfgList = getCfgList(config, kong.request, path)
  if nil == cfgList then
    if debug then
      kong.log.debug("No dynamic-route: " .. kong.request.get_method() .. " " .. path)
    end
    return
  end

  for i, cfg in ipairs(cfgList) do
    local condition_str = util.interpolate(cfg.condition, path, kong.request.get_method(), kong.client.get_forwarded_ip(), kong.request)
    if debug then
      kong.log.debug("Dynamic route condition_template: " .. path .. " -> " .. condition_str)
    end
    local dy_route = false
    if cfg.values then
      if tableContains(cfg.values, condition_str, cfg.case_sensitive) then
        dy_route = true
      end
    elseif cfg.not_values then
      if not tableContains(cfg.not_values, condition_str, cfg.case_sensitive) then
        dy_route = true
      end
    else
      kong.log.warn("Neither values nor not_values are defined for: " .. path)
    end
    if dy_route then
      if cfg.dynamic_host then
        local dynamic_port = cfg.dynamic_port or 80
        kong.service.set_target(cfg.dynamic_host, dynamic_port)
      elseif cfg.dynamic_upstream then
        local ok, err = kong.service.set_upstream(cfg.dynamic_upstream)
        if not ok then
          kong.log.err("Error setting upstream to: " .. cfg.rdynamic_upstream .. ", " .. err)
          return
        end
      else
        kong.log.err("Neither dynamic_host nor dynamic_upstream are defined for: " .. path)
      end
      -- we are done!
      break
    end
  end
end

-- set the plugin priority, which determines plugin execution order
plugin.PRIORITY = 830

-- return our plugin object
return plugin
