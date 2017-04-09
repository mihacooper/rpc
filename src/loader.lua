local root_dir = os.getenv("LUA_RPC_SDK") or "."
package.cpath = package.cpath .. ";" .. root_dir .. "/externals/effil/?.so"
package.cpath = package.cpath .. ";" .. root_dir .. "/externals/?.so"
package.path = package.path .. ";" .. root_dir .. "/externals/effil/?.lua"
package.path = package.path .. ";" .. root_dir .. "/externals/?.lua"

require "os"
require "string"
require "helpers"

return function(module_name, language, target)
    if not value_in_table(target, {'client', 'server'}) then
        return false, "Invalid target: " .. target
    end

    _G.target = target

    if module_name == nil or io.open(module_name, "r") == nil then
        return false, "Invalid module file: " .. module_name
    end

    require "dsl"
    local err, generator = pcall(require,  "lang-" .. language .. ".binding")
    if language == nil or not err then
        return false, "Invalid language: " .. language
    end

    local ret, err = pcall(dofile, module_name)
    if not ret then
        return false, err
    end
    return true, generator
end