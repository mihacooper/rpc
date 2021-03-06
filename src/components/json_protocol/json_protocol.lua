local json = require "json"

function encode(data)
    local ret, jdata = pcall(json.encode, data, true)
    if not ret then
        log_err("Unable to parse data to json:%s\n%s\n", jdata, table.show(data))
    end
    return jdata .. "\n"
end

function decode(jdata)
    local ret, data = pcall(json.decode, jdata)
    if not ret then
        log_err("Unable to parse data to json:%s\n%s\n", tostring(data), jdata)
    end
    return data
end

--[[
    Encoder
]]

function get_json_encode(connector, host, port)
    local json_protocol_encode = {
        connector = component:load(connector, host, port)
    }

    function json_protocol_encode:request_new(iface_name)
        assert(type(iface_name) == "string")
        log_dbg("Start request for new interface '%s'", iface_name)
        local response = self.connector:send_with_return(encode({ request = "new", interface = iface_name}))
        local response = decode(response)
        if response.result ~= 0 then
            log_err("Attept to create a new connection has failed, error: %s", response.msg)
        end
        if type(response.msg) ~= "string" or response.msg == "" then
            log_err("New connection has received invalid IID = %s", response.msg)
        end
        return response.msg
    end

    function json_protocol_encode:request_call(func, iid, ...)
        local data_to_send = { iid = iid, request = "call", method = func.type.name, args = {...} }
        local raw_response = encode(nil)
        if self.connector.send_with_return then
            raw_response = self.connector:send_with_return(encode(data_to_send))
            local response = decode(raw_response)
            if response.result ~= 0 then
                log_err("Connection got error: %s", response.msg)
            end
            return response.msg
        else
            self.connector:send(encode(data_to_send))
        end
    end

    function json_protocol_encode:request_del(iid)
        self.connector:send_with_return(encode { iid = iid, request = "close" })
    end
    return json_protocol_encode
end

--[[
    Decoder
]]

function get_json_decode(factory_name)
    local factory, err = component:load(factory_name)
    if not factory then
        log_err("Unable to load facotry '%s': %s", factory_name, err)
    end
    local json_protocol_decode = {
        factory = factory
    }

    function json_protocol_decode:process(data)
        local processor = {
            new = function(data)
                local status, id = self.factory:new(data.interface)
                if not status then
                    log_dbg("Factory return error: %s", id)
                    return false, { result = 1, msg = id }
                end
                self.iface = self.factory:get(id)
                if not self.iface then
                    log_dbg("Factory return iface = nil, id = %s", id)
                    return false, { result = 1, msg = "Unable to get iface instance" }
                end
                return false, { result = 0, msg = id }
            end,
            call = function(data)
                local method = self.iface[data.method]
                if method == nil then
                    return false, { result = 1, msg = "unknown method requested: " .. tostring(data.method)}
                end
                local call_res, call_ret = pcall(method, self.iface, unpack(data.args))
                if not call_res then
                    return true, { result = 1, msg = ("Exception occurs during method (%s) call: %s"):format(method, call_ret) }
                end
                return false, { result = 0, msg = call_ret }
            end,
            close = function(data)
                self.factory:del(data.iid)
                return true, { result = 0 }
            end
        }
        local decoded_data = decode(data)
        local request = decoded_data["request"]
        local data_to_send = ""
        if request == nil or processor[request] == nil then
            return false, encode({ result = 1, msg = "invalid request"})
        else
            local call_res, do_exit, response = pcall(processor[request], decoded_data)
            if not call_res then
                return false, encode({ result = 1, msg = do_exit })
            end
            return do_exit, encode(response)
        end
    end

    return json_protocol_decode
end

