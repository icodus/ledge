local util = require("ledge.util")

local setmetatable, pairs, type, tostring, error =
    setmetatable, pairs, type, tostring, error

local co_yield = coroutine.yield

local get_fixed_field_metatable_proxy =
    util.table.get_fixed_field_metatable_proxy


local _M = {
    _VERSION = "1.28.3",
}


local function new(config)
    local defaults = {
        interval = 1,
        gc_queue_concurrency = 1,
        purge_queue_concurrency = 1,
        revalidate_queue_concurrency = 1,
    }

    if config then
        -- Validate config has matching defaults
        for k, v in pairs(config) do
            local default_v = defaults[k]
            if not default_v or type(default_v) ~= type(v) then
                error("invalid config item or value type: " .. tostring(k), 3)
            end
        end
    end

    -- Apply defaults to config
    config = setmetatable(
        config or {},
        get_fixed_field_metatable_proxy(defaults)
    )

    return setmetatable({ config = config }, {
        __index = _M,
    })
end
_M.new = new


local function set(self, param, value)
    self.config[param] = value
end
_M.set = set


local function get(self, param)
    return self.config[param]
end
_M.get = get


local function run(self)
    local ledge = require("ledge")

    local redis_params = ledge.get("redis_params")
    local connection_params = {
        connect_timeout = redis_params.connect_timeout,
        read_timeout = redis_params.read_timeout,
    }

    local ql_worker = require("resty.qless.worker").new(
        redis_params.redis_connector,
        connection_params
    )

    ql_worker.middleware = function(job)
        job.redis = ledge.create_redis_connection()
        job.storage = ledge.create_storage_connection()

        co_yield()  -- Perform the job

        ledge.close_redis_connection(job.redis)
        ledge.close_storage_connection(job.storage)
    end

    assert(ql_worker:start({
        interval = self.config.interval,
        concurrency = self.config.gc_queue_concurrency,
        reserver = "ordered",
        queues = { "ledge_gc" },
    }))

    assert(ql_worker:start({
        interval = self.config.interval,
        concurrency = self.config.purge_queue_concurrency,
        reserver = "ordered",
        queues = { "ledge_purge" },
    }))

    assert(ql_worker:start({
        interval = self.config.interval or 1,
        concurrency = self.config.revalidate_queue_concurrency,
        reserver = "ordered",
        queues = { "ledge_revalidate" },
    }))
end
_M.run = run


return _M
