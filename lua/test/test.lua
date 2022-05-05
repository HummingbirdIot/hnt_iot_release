describe(
  "Busted unit testing framework",
  function()
    describe(
      "should be awesome",
      function()
        local PWD = os.getenv("PWD")
        if PWD then
          package.path = PWD .. "/lua/?.lua;" .. package.path
        end

        local util = require("util")
        local hiot = require("hummingbird_iot")
        it(
          "should be easy to use",
          function()
            assert.truthy("Yup.")
          end
        )

        it(
          "should have lots of features",
          function()
            -- deep check comparisons!
            assert.same({table = "great"}, {table = "great"})

            -- or check by reference!
            assert.is_not.equals({table = "great"}, {table = "great"})

            assert.falsy(nil)
            assert.error(
              function()
                error("Wat")
              end
            )
          end
        )

        it(
          "should provide some shortcuts to common functions",
          function()
            assert.unique({{thing = 1}, {thing = 2}, {thing = 3}})
          end
        )

        it(
          "util basic test should be ok",
          function()
            assert.same("hello", util.trim("hello  "))

            -- for split
            local test_str = "MINER_TAG=2022.04.27.0"
            local split_ret = util.split(test_str, "=")
            assert.same(#split_ret, 2)
            assert.same(split_ret[1], "MINER_TAG")
            assert.same(split_ret[2], "2022.04.27.0")

            local _, succuess = util.shell("nols /tmp")
            assert.falsy(succuess)
            local _, succuess_1 = util.shell("ls /tmp")
            assert.truthy(succuess_1)
            assert.falsy(util.upstreamUpdate(false))
            print(_VERSION)
            assert.truthy(util.tryWaitNetwork(5))

            local _tempFile = os.tmpname()
            assert.truthy(util.runAllcmd({"touch " .. _tempFile, "ls /tmp", "rm -f " .. _tempFile}))
            assert.falsy(util.runAllcmd({"notouch" .. _tempFile, "ls /tmp", "rm -f " .. _tempFile}))
          end
        )

        it(
          "util network check test should ok",
          function()
            assert.truthy(util.destIsReachable("taobao.com"))
            assert.falsy(util.destIsReachable("8.81.81.8"))
          end
        )

        it(
          "hiot basic self test should ok",
          function()
            assert.truthy(hiot.Test())
          end
        )
        it(
          "env test",
          function()
            assert.truthy(os.execute("export LUA_HIOT_TEST='1234'; env | grep LUA_HIOT_TEST"))
            assert.falsy(os.execute("export LUA_HIOT_TEST='1234'; env | grep LUA_HIOT_TEST1"))
          end
        )
        it(
          "load file to table test",
          --MINER_TAG=2022.04.27.0
          --PKT_FWD=hnt-pkt-fwd-cn470
          --PKT_FWD_VERSION=0.5.0

          function()
            local info = util.loadFileToTable("./lua/test/.env")
            assert.same(info.PKT_FWD, "hnt-pkt-fwd-cn470")
            assert.same(info.PKT_FWD_VERSION, "0.5.0")
            assert.same(info.MINER_TAG, "2022.04.27.0")
          end
        )
        it(
         "convert table to string for save",
          function()
            local str0 = "MINER_TAG=2022.04.27.0\n"
            local str1 = "PKT_FWD=hnt-pkt-fwd-cn470\n"
            local str2 = "PKT_FWD_VERSION=0.5.0\n"

            local info = {MINER_TAG = "2022.04.27.0", PKT_FWD = "hnt-pkt-fwd-cn470", PKT_FWD_VERSION = "0.5.0"}
            local tableStr = util.tableToString(info);
            print(tableStr)
            assert.is_not(string.find(tableStr, str0), nil)
            assert.is_not(string.find(tableStr, str1), nil)
            assert.is_not(string.find(tableStr, str2), nil)
          end
          )
        it("get default lora region should region_cn470",
          function ()
            assert.same(hiot.GetDefaultLoraRegion(), "region_cn470")

            assert.same("export PKT_FWD=hnt-pkt-fwd-cn470;", hiot.GetDockerEnvAndSetRuntimeInfo(true))
            assert.same("hnt-pkt-fwd-cn470", hiot.loraRegions["region_cn470"].pkt_fwd)
          end
          )
      end
    )
  end
)
