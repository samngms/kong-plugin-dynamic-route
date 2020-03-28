local typedefs = require "kong.db.schema.typedefs"

return {
  name = "dynamic-route",
  fields = {
    { consumer = typedefs.no_consumer },
    { config = {
      type = "record",
      fields = {
        { debug = { type = "boolean", default = false } },
        { exact_match = {
          type = "map",
          -- the key is the path of the url
          keys = {
            type = "string"
          },
          values = {
            -- the next key is http method
            type = "map",
            keys = {
              type = "string"
            },
            values = {
              type = "array",
              elements = {
                type = "record",
                fields = {
                  { condition = { type = "string", required = true } },
                  { values = { type = "array" , elements = { type = "string" } } },
                  { not_values = { type = "array" , elements = { type = "string" } } },
                  { case_sensitive = { type = "boolean", default = true } },
                  { dynamic_host = { type = "string" } },
                  { dynamic_port = { type = "number" } },
                  { dynamic_upstream = { type = "string"} }
                }
              }
            }              
          }
        }},
        { pattern_match = {
          type = "map",
          -- the key is the path of the url
          keys = {
            type = "string"
          },
          values = {
            -- the next key is http method
            type = "map",
            keys = {
              type = "string"
            },
            values = {
              type = "array",
              elements = {
                type = "record",
                fields = {
                  { condition = { type = "string", required = true } },
                  { values = { type = "array" , elements = { type = "string" } } },
                  { not_values = { type = "array" , elements = { type = "string" } } },
                  { case_sensitive = { type = "boolean", default = true } },
                  { dynamic_host = { type = "string" } },
                  { dynamic_port = { type = "number" } },
                  { dynamic_upstream = { type = "string"} }
                }
              }
            }              
          }
        }}
      }
    }}
  }
}
