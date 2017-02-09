# Copyright (c) 2015-2017, Blockbridge Networks LLC.  All rights reserved.  Use
# of this source code is governed by a BSD-style license, found in the LICENSE
# file.

module Blockbridge
  class Startup
    include Helpers
    attr_reader :config
    attr_reader :logger
    attr_reader :status

    def initialize(address, port, config, status, logger)
      @config = config
      @logger = logger
      @status = status
    end

    def run
      start_iscsid(startup: true)
    end
  end
end
