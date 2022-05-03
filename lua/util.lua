local util = {}
local requireRel

--local selfPath = debug.getinfo(1,"S").source:sub(2)
if ... then
  local d = (...):match("(.-)[^%\\/]+$")
  function requireRel(module)
    return require(d .. module)
  end
elseif arg and arg[0] then
  package.path = arg[0]:match("(.-)[^\\/]+$") .. "?.lua;" .. package.path
  requireRel = require
end

local file = require("lua/file")

assert(file.exists)

local OTA_STATUS_FILE = "/tmp/hummingbird_ota"

function IsDarwin()
  return io.popen("uname -s", "r"):read("*l") == "Darwin"
end

function util.runAllcmd(cmds)
  ---@diagnostic disable-next-line: unused-local
  for _k, cmd in pairs(cmds) do
    if not os.execute(cmd) then
      print("fail to exec " .. cmd)
      return false
    end
  end
  return true
end

function util.trim(s)
  return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

function util.shell(cmd)
  local fileHandle = assert(io.popen(cmd, "r"))
  local commandOutput = assert(fileHandle:read("*a"))
  local success = fileHandle:close()
  return commandOutput, success
end

function util.tryWaitNetwork(timeout)
  local tryNum = timeout or 30
  local gw, success = util.shell("ip r | grep default | cut -d ' ' -f 3 | head -n 1")
  if success then
    print("GW " .. gw)
    while (tryNum > 0) do
      if util.destIsReachable(gw) then return true end
      print("retry times: " .. tostring(tryNum))
      tryNum = tryNum - 1
    end
    print("Networking check ok ...")
  end
  return false
end

function util.destIsReachable(dest)
  local cmd
  if (IsDarwin()) then
    cmd = "ping -q -t 1 -c 1 " .. dest
  else
    cmd = "ping -q -w 1 -c 1 " .. dest
  end
  return os.execute(cmd)
end

function util.gitSetup()
  local cmds = {
    "git config user.email 'hummingbirdiot@example.com'",
    "git config user.name 'hummingbirdiot'"
  }
  return util.runAllcmd(cmds)
end

function util.upstreamUpdate(useSudo)
  local branch, success = util.shell("git rev-parse --abbrev-ref HEAD")
  if not success then
    return false
  end
  local cmd = "git fetch origin " .. branch
  print("cmd is " .. cmd)
  if useSudo then
    cmd = "sudo " .. cmd
  end
  if os.execute(cmd) then
    local headHash, success_1 = util.shell("git rev-parse HEAD")
    if not success_1 then
      return false
    end
    headHash = util.trim(headHash)
    local upstreamHash, success_2 = util.shell("git rev-parse @{upstream}")
    if not success_2 then
      return false
    end
    upstreamHash = util.trim(upstreamHash)
    print(headHash .. " " .. upstreamHash)
    return headHash ~= upstreamHash
  end
end

function util.syncToUpstream(useSudo, cleanFunc)
  if util.upstreamUpdate(useSudo) and not file.exists(OTA_STATUS_FILE) then
    print("Do self update")
    file.write(OTA_STATUS_FILE, os.date(), "w")
    cleanFunc()
    util.runAllcmd({
        "sudo git stash",
        "sudo git merge '@{u}'",
        "sudo chmod +x hummingbird_iot.sh"
      })
    file.remove(OTA_STATUS_FILE)
    if not os.execute("sudo ./hummingbird_iot.sh lua")  ~= 0 then print("Fail to start hiot") end
    os.exit(0)
  end
  return true
end

function util.FreeDiskPressure(usage)
  local thresh = usage or 80
  print("In FreeDiskPressure")
  local diskUsage, success = util.shell("df -h |grep '/dev/root' | awk '{print $5}' | tr -dc '0-9'")
  if not success then print("Fail to get diskUsage") return false end
  if tonumber(diskUsage) > thresh then
    print("trim miner for " .. diskUsage .. " hight then " .. tostring(thresh))
    os.execute('sudo bash ./trim_miner.sh createSnap')
  end
end

return util
