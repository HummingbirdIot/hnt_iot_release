describe('Busted unit testing framework', function()
  describe('should be awesome', function()
    it('should be easy to use', function()
      assert.truthy('Yup.')
    end)

    it('should have lots of features', function()
      -- deep check comparisons!
      assert.same({ table = 'great'}, { table = 'great' })

      -- or check by reference!
      assert.is_not.equals({ table = 'great'}, { table = 'great'})

      assert.falsy(nil)
      assert.error(function() error('Wat') end)
    end)

    it('should provide some shortcuts to common functions', function()
      assert.unique({{ thing = 1 }, { thing = 2 }, { thing = 3 }})
    end)

    describe('util basic test', function()
      local PWD = os.getenv("PWD")
      if PWD then package.path = PWD .. "/lua/?.lua;" .. package.path end

      local util = require('util')

      assert.same("hello", util.trim("hello  "))
      local _output, succuess = util.shell("nols /tmp")
      assert.falsy(succuess)
      local _output1, succuess_1 = util.shell("ls /tmp")
      assert.truthy(succuess_1)
      assert.falsy(util.upstreamUpdate(false))
      assert.truthy(util.tryWaitNetwork(1))

      local _tempFile = os.tmpname();
      assert.truthy(util.runAllcmd({"touch " .. _tempFile, "ls /tmp", "rm -f " .._tempFile}))
      assert.falsy(util.runAllcmd({"notouch" .. _tempFile, "ls /tmp", "rm -f " .._tempFile}))
    end)
  end)
end)
