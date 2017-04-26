local pairs, unpack = pairs, unpack
local tbl_insert = table.insert
local ngx_log = ngx.log
local ngx_ERR = ngx.ERR
local ngx_null = ngx.null


local _M = {
    _VERSION = '1.28.3',
}


-- Cleans up expired items and keeps track of memory usage.
function _M.perform(job)
    local storage = job.storage
    if not storage then
        return nil, "job-error", "no storage driver provided"
    end

    local ok, err = storage:delete(job.data.entity_id)
    if not ok or ok == ngx_null then
        return nil, "job-error",
            "could not collect entity: " .. job.data.entity_id ..
            " because: " .. err
    end
end


return _M

