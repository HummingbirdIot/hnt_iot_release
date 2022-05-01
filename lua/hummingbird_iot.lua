local hummingbird_iot = {}

local file = require("lua/file")

function getDockerComposeConfig()
    local modelFile = "/proc/device-tree/model"
    if file.exists(modelFile) then
        local content = file.read(modelFile, "*a")
        local start = string.find(content, 'Raspberry Pi')
        if start then return "docker-compose.yaml" end
    end
    return "docker-compose-v2.yaml"
end

function GetCurrentLuaFile()
    local source = debug.getinfo(2, "S").source
    if source:sub(1,1) == "@" then
        return source:sub(2)
    else
        error("Caller was not defined in a file", 2)
    end
end

function PatchTargetFile(Src, Dest)
    local cmd = "diff " .. Src .. " " .. Dest
    if file.exists(Src) then
        print(cmd)
        if os.execute(cmd) ~= 0 then
            file.copy(Src, Dest)
            return true
        end
    else
        print(Src .. "Not Exist just ingore");
    end
    return false
end

function hummingbird_iot:PatchServices()
    local ServicesToPatch = {
        { name = "test2", src ="/tmp/test3", dest = "/tmp/test4" },
        { name = "test1", src ="/tmp/test1", dest = "/tmp/test2" },
    }

    for _k,v in pairs(ServicesToPatch) do
        print("check for " .. v.name)
        if PatchTargetFile(v.src, v.dest) then
            print("restart service")
        end
    end
end

function hummingbird_iot:Run()
  print(">>>>> hummingbirdiot start <<<<<<")
  print(GetCurrentLuaFile())

  hummingbird_iot:PatchServices();
end

print(getDockerComposeConfig())
--if #arg == 0 then
--  hummingbird_iot:Run()
--end
