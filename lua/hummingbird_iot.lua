local hummingbird_iot = {}

local file = require("file")

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

if #arg == 0 then
  hummingbird_iot:Run()
end
