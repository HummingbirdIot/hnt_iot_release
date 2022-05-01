local HIoT = {}

local file = require("lua/file")
local DockerComposeBin = "docker-compose"

function HIoT.GetDockerComposeConfig()
  local modelFile = "/proc/device-tree/model"
  if file.exists(modelFile) then
    local content = file.read(modelFile, "*a")
    local start = string.find(content, "Raspberry Pi")
    if start then
      return "docker-compose.yaml"
    end
  end
  return "docker-compose-v2.yaml"
end

function HIoT.StopDockerCompose()
  local config = HIoT.GetCurrentLuaFile()
  print("Stop hummingbird_iot docker compose with config " .. config)
  local cmd = DockerComposeBin .. " -f " .. config .. " down"
  if not os.execute(cmd) then
    print("fail to stop docker with " .. cmd)
  end
end

function HIoT.GetCurrentLuaFile()
  local source = debug.getinfo(2, "S").source
  if source:sub(1, 1) == "@" then
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
    print(Src .. "Not Exist just ingore")
  end
  return false
end

function HIoT:PatchServices()
  local ServicesToPatch = {
    {name = "test2", src = "/tmp/test3", dest = "/tmp/test4"},
    {name = "test1", src = "/tmp/test1", dest = "/tmp/test2"}
  }

  for _, v in pairs(ServicesToPatch) do
    print("check for " .. v.name)
    if PatchTargetFile(v.src, v.dest) then
      print("restart service")
    end
  end
end

function HIoT:Run()
  print(">>>>> hummingbirdiot start <<<<<<")
  print(GetCurrentLuaFile())

  HIoT:PatchServices()
end

--if #arg == 0 then
--  hummingbird_iot:Run()
--end

return HIoT
