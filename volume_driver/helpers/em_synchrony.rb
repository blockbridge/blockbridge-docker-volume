# Copyright (c) 2015-2017, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.
require 'em-synchrony'

module EventMachine
  module Synchrony
    def self.run_and_add_periodic_timer(time_s, &blk)
      EM::Synchrony.next_tick(&blk)
      EM::Synchrony.add_periodic_timer(time_s, &blk)
    end
  end
end
