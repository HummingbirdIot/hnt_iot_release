local lightGW = {}

local json = require("lua/json")
local util = require("lua/util")

function lightGW.GetMinerRegion()
  local info, succuess = util.shell('helium_gateway info -k region')
  if succuess then
    local data = json.decode(info)
    if data and data.region then return data.region end
  end
end

function lightGW.Stop()
  if not os.execute("sudo systemctl stop helium_gateway") then
    print("fail to stop helium gateway")
  end
end

function lightGW.Start()
  if not os.execute("sudo systemctl start helium_gateway") then
    print("fail to start helium gateway")
  end
  print("Started helium_gateway")
end

return lightGW