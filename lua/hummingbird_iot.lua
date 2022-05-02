local HIoT = {}

local file = require("lua/file")
local util = require("lua/util")
local DockerComposeBin = "docker-compose"

function Sleep(n)
  os.execute("sleep " .. tonumber(n))
end

function GetDockerComposeConfig()
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

function StopDockerCompose()
  local config = GetDockerComposeConfig()
  print("Stop hummingbird_iot docker compose with config " .. config)
  local cmd = DockerComposeBin .. " -f " .. config .. " down"
  if os.execute(cmd) == 0 then return true
  else
    print("fail to stop docker with " .. cmd)
  end
  return false
end

function StartDockerCompose()
  local config = GetDockerComposeConfig()
  print("Start hummingbird_iot docker compose with config " .. config)
  local cmd = DockerComposeBin .. " -f " .. config .. " up -d"
  if os.execute(cmd) == 0 then return true
  else
    print("fail to start docker with " .. cmd)
  end
  return false
end

function PruneDockerImages()
  StopDockerCompose()
  local cmd = "sudo docker images -a | grep \"miner-arm64\" | awk '{print $3}' | xargs docker rmi"
  if os.execute(cmd) ~= 0 then print("PruneDockerImages failed") end
end

function StartHummingbird(tryPrune, retryNum)
  print("Start Hummingbrid tryPrune: " .. tostring(tryPrune) .. " retryNum num: " .. tostring(retryNum))
  local tryNum = retryNum or 30
  while (tryNum > 0) do
    if StartDockerCompose() then return true end
    print("retry times: " .. tostring(tryNum))
    tryNum = tryNum - 1
    Sleep(1)
  end

  if not util.destIsReachable('8.8.8.8') then return false end
  print("Networking check ok ...")
  if not tryPrune then return false end
  StopDockerCompose()
  -- Try Prune the docker images
  PruneDockerImages()
  return StartHummingbird(false, 3)
end

function GetCurrentLuaFile()
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
      return os.execute("sudo cp " .. Src .. " " .. Dest)
    end
  else
    print("!!! error:" .. Src .. " or " .. Dest .. "Not Exist just ingore")
  end
  return false
end

function PatchServices()
  local ServicesToPatch = {
    {
      name = "dhcpcd",
      src = "config/patch/wait.conf",
      dest = "/etc/systemd/system/dhcpcd.service.d/wait.conf",
      action = "sudo systemctl daemon-reload; sudo systemctl restart dhcpcd"
    },
    {
      name = "hiotTimer",
      src = "config/patch/hiot.timer",
      dest = "/etc/systemd/system/hiot.timer",
      action = "sudo systemctl daemon-reload; sudo systemctl restart hiot.timer"
    },
    {
      name = "avahi",
      src = "config/patch/avahi-daemon.conf",
      dest = "/etc/avahi/avahi-daemon.conf",
      action = "sudo systemctl daemon-reload; sudo systemctl restart avahi-daemon"
    },
    {
      name = "journald",
      src = "config/patch/journald.conf",
      dest = "/etc/systemd/journald.conf",
      action = "sudo systemctl daemon-reload; sudo systemctl restart systemd-journald.service"
    },
    {
      name = "dbus-miner",
      src = "config/com.helium.Miner.conf",
      dest = "/etc/dbus-1/system.d/com.helium.Miner.conf",
      action = "sudo systemctl daemon-reload; sudo systemctl restart dbus"
    },
    {
      name = "dbus-config",
      src = "config/com.helium.Config.conf",
      dest = "config/com.helium.Config.conf",
      action = "sudo systemctl daemon-reload; sudo systemctl restart hiot.timer"
    },
    {
      name = "update release version",
      src = "config/lsb_release",
      dest = "/etc/lsb_release"
    }
  }

  for _, v in pairs(ServicesToPatch) do
    print("check for " .. v.name)
    if PatchTargetFile(v.src, v.dest) and v.action then
      if os.execute(v.action) ~= 0 then print("failed do post action " .. v.action .. " for " .. v.name) end
    end
  end
end

function HIoT.Test()
  local fileId = GetCurrentLuaFile()
  assert(file and util)
  assert(string.find(fileId, "hummingbird_iot.lua") ~= nil)
  assert(GetDockerComposeConfig() == "docker-compose-v2.yaml")
  return true
end

function CheckPublicKeyFile()
  os.execute("sudo mkdir -p /var/data && sudo touch /var/data/public_keys")
end

function CleanSaveSnapshot()
  local cmd = os.execute("find /var/data/saved-snaps/ -type f -printf \"%T@ %p\\n\" | sort -r | awk 'NR==2,NR=NRF {print $2}' | xargs -I {} rm {}")
  if os.execute(cmd) ~= 0 then
    print("!!! Failed to clean snapshot with " .. cmd)
  end
end

function HIoT.Run()
  print(">>>>> hummingbirdiot start <<<<<<")
  print(GetCurrentLuaFile())
  CleanSaveSnapshot()
  PatchServices()
  util.tryWaitNetwork()
  util.FreeDiskPressure()
  util.gitSetup()
  CheckPublicKeyFile()
  util.syncToUpstream(true, StopDockerCompose)
  os.execute('sudo rfkill unblock all')
  StartHummingbird(true)
end

if arg[1] == "run" then
  HIoT.Run()
else
  return HIoT
end
