local helpers = require "spec.helpers"
local version = require("version").version or require("version")

local PLUGIN_NAME = "dynamic-route"
local KONG_VERSION
do
  local _, _, std_out = assert(helpers.kong_exec("version"))
  if std_out:find("[Ee]nterprise") then
    std_out = std_out:gsub("%-", ".")
  end
  std_out = std_out:match("(%d[%d%.]+%d)")
  KONG_VERSION = version(std_out)
end

for _, strategy in helpers.each_strategy() do
  describe(PLUGIN_NAME .. ": (basic URL tests) [#" .. strategy .. "]", function()
    local client

    lazy_setup(function()
      local bp, route1
      local myconfig = {
        debug = true,
        exact_match = {
          ["/get"] = {
            ["*"] = {
              [1] = {
                condition = "${query.do_it}",
                values = {"by_host"},
                dynamic_host = "httpbin.org",
                dynamic_port = 443
              },
              [2] = {
                condition = "${query.do_it}",
                values = {"by_upstream"},
                dynamic_upstream = "upstream1"
              }
            }
          }
        }
      }

      if KONG_VERSION >= version("0.35.0") or
         KONG_VERSION == version("0.15.0") then
        --
        -- Kong version 0.15.0/1.0.0+, and
        -- Kong Enterprise 0.35+ new test helpers
        --
        local bp = helpers.get_db_utils(strategy, nil, { PLUGIN_NAME })

        local service1 = bp.services:insert{
          protocol = "https",
          host     = "postman-echo.com",
          port     = 443,
        }

        local route1 = bp.routes:insert({
          hosts = { "postman-echo.com" },
          service = service1
        })

        local upstream1 = assert(bp.upstreams:insert({
          name = "upstream1"
        }))
  
        assert(bp.targets:insert({
          upstream = upstream1,
          target = "httpbin.org:443",
          weight = 100,
        }))

        bp.plugins:insert {
          name = PLUGIN_NAME,
          route = { id = route1.id },
          config = myconfig
        }

      else
        --
        -- Kong Enterprise 0.35 older test helpers
        -- Pre Kong version 0.15.0/1.0.0, and
        --
        local bp = helpers.get_db_utils(strategy)

        local service1 = bp.services:insert{
          protocol = "https",
          host     = "postman-echo.com",
          port     = 443,
        }

        local route1 = bp.routes:insert({
          hosts = { "postman-echo.com" },
          service = service1
        })

        local upstream1 = assert(bp.upstreams:insert({
          name = "upstream1"
        }))
  
        assert(bp.targets:insert({
          upstream = upstream1,
          target = "httpbin.org:443",
          weight = 100,
        }))

        bp.plugins:insert {
          name = PLUGIN_NAME,
          route_id = route1.id,
          config = myconfig
        }
      end

      -- start kong
      assert(helpers.start_kong({
        -- set the strategy
        database   = strategy,
        -- use the custom test template to create a local mock server
        -- nginx_conf = "spec/fixtures/custom_nginx.template",
        -- set the config item to make sure our plugin gets loaded
        plugins = "bundled," .. PLUGIN_NAME,  -- since Kong CE 0.14
        custom_plugins = PLUGIN_NAME,         -- pre Kong CE 0.14
      }))
    end)

    lazy_teardown(function()
      helpers.stop_kong(nil, true)
    end)

    before_each(function()
      client = helpers.proxy_client()
    end)

    after_each(function()
      if client then client:close() end
    end)

    describe("testing ", function()

      it("No reroute", function()
        local r = assert(client:send {
          method = "GET",
          path = "/get",
          headers = {
            host = "postman-echo.com",
            ["Content-Type"] = "application/x-www-form-urlencoded"
          },
          query = "do_it=foobar"
        })
        assert.response(r).has.status(200)
        local server = assert.response(r).has.header("server")
        -- default goes to postman-echo.com, the "Server" header in http response is "nginx"
        assert.equals(server, "nginx")
      end)

      it("Reroute by host", function()
        local r = assert(client:send {
          method = "GET",
          path = "/get",
          headers = {
            host = "postman-echo.com",
            ["Content-Type"] = "application/x-www-form-urlencoded"
          },
          query = "do_it=by_host"
        })
        assert.response(r).has.status(200)
        local server = assert.response(r).has.header("server")
        -- reroute to httpbin.org, the "Server" header in http response is "gunicorn/19.9.0"
        assert.equals(server:sub(1, 8), "gunicorn")
      end)

      it("Reroute by upstream", function()
        local r = assert(client:send {
          method = "GET",
          path = "/get",
          headers = {
            host = "postman-echo.com",
            ["Content-Type"] = "application/x-www-form-urlencoded"
          },
          query = "do_it=by_upstream"
        })
        assert.response(r).has.status(200)
        local server = assert.response(r).has.header("server")
        -- reroute to httpbin.org, the "Server" header in http response is "gunicorn/19.9.0"
        assert.equals(server:sub(1, 8), "gunicorn")
      end)

    end)

  end)
end
