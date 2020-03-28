# kong-plugin-dynamic-route

A dynamic route plugin for Kong API Gateway

The following are global config parameters

| Parameter | Parameter Type | Description |
|-----------|:---------------|:------------|
| `debug` | `boolean` | if true, will return rejection reason in HTTP response body |

Per each url path and for each HTTP method, you can specify an array with the following fields

| Field name | Field type | Description |
|-----------|:-----------------|:------------|
| `condition` | `string` | Detail description see below |
| `values` | `string[]` | the matching value of `condition_template` to trigger the dynamic route |
| `not_values` | `string[]` | the matching value of `condition_template` to NOT trigger the dynamic route |
| `dynamic_host` | `string` | re-route the destintation to this host, you need to specify `port` as well |
| `dynamic_port` | `number` | the port number of the new destination |
| `dynamic_upstream` | `string` | re-route the desintation to a new upstream, this is the name of the upstream, the routing will not work if this upstream name does not exist |

`condition` is a string that supporting the following variable substitutions
- `${method}`: the request method
- `${url}`: the url path, does NOT include querystring
- `${ip}`: the result of `kong.client.get_forwarded_ip()`
- `${header.xxx}`: the result of `kong.request.get_header(xxx)`, note `-` is supported
- `${query.xxx}`: the result of `kong.request.get_query()[xxx]`
- `${body.xxx}`: the result of `kong.request.get_body()[xxx]`

# Configuration

There are two types of paths in the config, `exact_match` and `pattern_match`, we currently only support `exact_match`

```js
"/path1/path2": {
    "GET": [
        {
            "condition": "${method}|${query.name}",
            "values": ["GET|john", "POST|doe"],
            "dynamic_host": "foobar.com",
            "dynamic_port": 443
        },
        {
            "condition": "${header.country}",
            "values": ["Argentina", "Mexico", "Spain"],
            "dynamic_upstream": "es_upstream"
        }
    ],
    "POST": [
        ...
    ]
}
```
In the above setting, the path `/path1/path2` `GET` will be dynamically routed according to
- If HTTP method is `GET` and query parameter `name` is `john`, it will be routed to `foobar:443`
- If HTTP method is `POST` and query parameter `name` is `doe`, it will be routed to `foobar:443`
- If HTTP header `country` is either one of `Argentina`, `Mexico`, `Spain`, it will be route to Kong upstream `es_upstream`

# Testing the plugin

The easiest way to test Kong plugin is by using [kong-pongo](https://github.com/Kong/kong-pongo)

```sh
$ git clone https://github.com/Kong/kong-pongo ../kong-pongo
$ KONG_VERSION=1.4.x ../kong-pongo/pongo.sh run -v -o gtest ./spec
```

All the Kong server logs can be found in `./servroot/logs`

# About luarocks

If you use `brew install kong`, it actually install both `kong` and `openresty`, with `luarocks` installed under `openresty`

Therefore, when you run `luarocks`, you can see there are two trees
- `<your_home>/.luarocks`
- `<path_to_openresty>/luarocks`

However, the rock should be installed inside `kong`, not inside `openresty`

# Installation

To install the plugin into `kong`

```shell script
# luarocks --tree=<path_to_kong> install
```

For example, `path_to_kong` on my machine is `/usr/local/Cellar/kong/1.2.2/`

# Uninstall

```shell script
# luarocks --tree=<path_to_kong> remove kong-plugin-dynamic-route
```
