# Copyright (c) 2015-2016, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

module Helpers
  module Sync
    def self.locks
      @@locks ||= {}
    end

    def synchronize(&blk)
      lock = Sync.locks[vol_name] ||= {
        mutex: EM::Synchrony::Thread::Mutex.new,
        ref:   0
      }
      lock[:ref] += 1
      lock[:mutex].synchronize(&blk)
      lock[:ref] -= 1
      Sync.locks.delete(vol_name) if lock[:ref] == 0
    end

    def defer(&blk)
      res = EM::Synchrony.defer do
        begin
          blk.call
        rescue => e
          e
        end
      end
    end
  end
end
