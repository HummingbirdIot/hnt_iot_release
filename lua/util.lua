local util = {}

function util.osExecute(cmd)
  local fileHandle     = assert(io.popen(cmd, 'r'))
  local commandOutput  = assert(fileHandle:read('*a'))
  local returnTable    = {fileHandle:close()}
  return commandOutput,returnTable[3]            -- rc[3] contains returnCode
end

function util.tryWaitNetwork(timeout)
  local tryNum = timeout or 30;
  local gw, err = util.osExecute("ip r | grep default | cut -d ' ' -f 3 | head -n 1");
  if err == 0 then
    print("GW " .. gw)
    while (tryNum > 0)
    do
      if os.execute("ping -q -t 1 -c 1 " .. gw) then break end
      --if os.execute("ping -q -w 1 -c 1" .. result) then break end
      print("retry times: " .. tostring(tryNum))
      tryNum = tryNum - 1
    end
    print("Networking check ok ...")
  end
end

function util.gitSetup()
  local cmds = {
    "git config user.email 'hummingbirdiot@example.com'",
    "git config user.name 'hummingbirdiot'",
  }

  for _k, cmd in pairs(cmds) do
    if not os.execute(cmd) then
      print("fail to exec " .. cmd)
      break
    end
  end
end

function util.upstreamUpdate()
  local branch, err = util.osExecute("git rev-parse --abbrev-ref HEAD")
  if err ~= 0 then return false end
  print("branch is " .. branch)
  if os.execute("sudo git fetch origin " .. branch) then
    local headHash, err_1 = util.osExecute("git rev-parse HEAD")
    if err_1 ~= 0 then return false end
    local upstreamHash, err_2 = util.osExecute("git rev-parse @{upstream}")
    if err_2 ~= 0 then return false end
    print(headHash .. " " .. upstreamHash)
    return headHash ~= upstreamHash
  end
end

return util
