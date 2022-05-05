local hiot = {}

local file = require("lua/file")
local util = require("lua/util")
local DockerComposeBin = "docker-compose"

hiot.loraRegions = {
  cn470 = {name = "cn470", pkt_fwd = "hnt-pkt-fwd-cn470"},
  eu868 = {name = "eu868", pkt_fwd = "hnt-pkt-fwd-eu868"},
  us915 = {name = "us915", pkt_fwd = "hnt-pkt-fwd-us915"},
  region_cn470 = {name = "cn470", pkt_fwd = "hnt-pkt-fwd-cn470"},
  region_eu868 = {name = "eu868", pkt_fwd = "hnt-pkt-fwd-eu868"},
  region_us915 = {name = "us915", pkt_fwd = "hnt-pkt-fwd-us915"}
}

local undefined_region = "undefined"
local hiotRuntimeConfig = "./.hummingbird_iot_runtime"

function hiot.GetMinerRegion()
  local region, succuess = util.shell("docker exec hnt_iot_helium-miner_1 miner info region")
  if succuess then
    return string.lower(region)
  end
  return undefined_region
end

function hiot.GetAndSetRuntimeInfo(skipSetRuntime)
  local skipSet = skipSetRuntime or false
  local hiotRuntime = {region = hiot.GetMinerRegion()}
  -- load from lst
  local info = util.loadFileToTable(hiotRuntimeConfig)

  if hiotRuntime.region == undefined_region then
    hiotRuntime.region = info.region
  elseif hiotRuntime.region ~= info.region and not skipSet then
    -- update runtime info
      local hiotRuntimeStr = util.tableToString(hiotRuntime)
      file.write(hiotRuntimeConfig, hiotRuntimeStr, "w")
  end
  return hiotRuntime
end

function hiot.GetDefaultLoraRegion()
  local info = util.loadFileToTable("/etc/hummingbird_iot.config")
  if info.region and info.region ~= undefined_region then
    return info.region
  end
  return hiot.loraRegions.cn470.name
end

local function Sleep(n)
  os.execute("sleep " .. tonumber(n))
end

local function GetDockerComposeConfig()
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

local function StopDockerCompose()
  local config = GetDockerComposeConfig()
  print("Stop hummingbird_iot docker compose with config " .. config)
  local cmd = DockerComposeBin .. " -f " .. config .. " down"
  if os.execute(cmd) then
    return true
  else
    print("fail to stop docker with " .. cmd)
  end
  return false
end

function hiot.GetDockerEnvAndSetRuntimeInfo(skipSetRuntime)
  local skipSet = skipSetRuntime or false
  local runtimeRegion = hiot.GetAndSetRuntimeInfo(skipSet).region
  if runtimeRegion then print(" runtime region >>>> " .. runtimeRegion) end
  local region = hiot.loraRegions[runtimeRegion]
  local dockerEnv = ""

  if region and region.pkt_fwd then print("runtime region pkt_fwd >>>> " .. region.pkt_fwd) end
  if not (region and region.pkt_fwd) then
    region = hiot.loraRegions[hiot.GetDefaultLoraRegion()]
  end

  if region then
    dockerEnv = "export PKT_FWD=" .. region.pkt_fwd .. ";"
  else
    print("!!!error get GetDefaultLoraRegion return", hiot.GetDefaultLoraRegion())
  end

  return dockerEnv
end

local function StartDockerCompose()
  local config = GetDockerComposeConfig()
  local dockerEnv = hiot.GetDockerEnvAndSetRuntimeInfo()
  local cmd = dockerEnv .. DockerComposeBin .. " -f " .. config .. " up -d"
  print("StartHummingbird with cmd: " .. cmd)
  if os.execute(cmd) then
    return true
  else
    print("fail to start docker with " .. cmd)
  end
  return false
end

function hiot.PruneDockerImages()
  StopDockerCompose()
  local cmd = 'sudo docker images -a | grep "miner-arm64" | awk \'{print $3}\' | xargs docker rmi'
  if not os.execute(cmd) then
    print("PruneDockerImages failed")
  end
end

local function StartHummingbird(tryPrune, retryNum)
  print("Start Hummingbrid tryPrune: " .. tostring(tryPrune) .. " retryNum num: " .. tostring(retryNum))
  local tryNum = retryNum or 30
  while (tryNum > 0) do
    if StartDockerCompose() then
      return true
    end
    print("retry times: " .. tostring(tryNum))
    tryNum = tryNum - 1
    Sleep(1)
  end

  if not util.destIsReachable("8.8.8.8") then
    return false
  end
  print("Networking check ok ...")
  if not tryPrune then
    return false
  end
  StopDockerCompose()
  -- Try Prune the docker images
  hiot.PruneDockerImages()
  return StartHummingbird(false, 3)
end

local function GetCurrentLuaFile()
  local source = debug.getinfo(2, "S").source
  if source:sub(1, 1) == "@" then
    return source:sub(2)
  else
    error("Caller was not defined in a file", 2)
  end
end

local function PatchTargetFile(Src, Dest)
  local cmd = "diff " .. Src .. " " .. Dest
  if file.exists(Src) then
    print(cmd)
    if not os.execute(cmd) then
      return os.execute("sudo cp " .. Src .. " " .. Dest)
    end
  else
    print("!!! error:" .. Src .. " or " .. Dest .. "Not Exist just ingore")
  end
  return false
end

local function PatchServices()
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
      dest = "/etc/dbus-1/system.d/com.helium.Config.conf",
      action = "sudo systemctl daemon-reload; sudo systemctl restart dbus"
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
      if not os.execute(v.action) then
        print("failed do post action " .. v.action .. " for " .. v.name)
      end
    end
  end
end

function hiot.Test()
  local fileId = GetCurrentLuaFile()
  assert(file and util)
  assert(string.find(fileId, "hummingbird_iot.lua") ~= nil)
  assert(GetDockerComposeConfig() == "docker-compose-v2.yaml")
  return true
end

local function CheckPublicKeyFile()
  os.execute("sudo mkdir -p /var/data && sudo touch /var/data/public_keys")
end

function hiot.CleanSaveSnapshot()
  local cmd =
    'find /var/data/saved-snaps/ -type f -printf "%T@ %p\\n" | ' ..
    "sort -r | awk 'NR==2,NR=NRF {print $2}' | xargs -I {} rm {}"
  if not os.execute(cmd) then
    print("!!! Failed to clean snapshot with " .. cmd)
  end
end

local function EnableBlueTooth()
  if not os.execute("sudo rfkill unblock all") then
    print("Fail to enable bluetooth")
  end
end

function hiot.Run()
  print(">>>>> hummingbirdiot start <<<<<<")

  print(GetCurrentLuaFile())
  hiot.CleanSaveSnapshot()
  PatchServices()
  util.tryWaitNetwork()
  util.FreeDiskPressure()
  util.gitSetup()
  CheckPublicKeyFile()
  EnableBlueTooth()
  util.syncToUpstream(true, StopDockerCompose)
  StartHummingbird(true)
  -- check for hm_diage upgrade
  os.execute("bash ./hm_diag_upgrade.sh")
end

if arg[1] == "run" then
  hiot.Run()
else
  return hiot
end
