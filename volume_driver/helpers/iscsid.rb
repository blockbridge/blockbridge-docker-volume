# Copyright (c) 2015-2016, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

require 'posix/spawn'

module Helpers
  module Iscsid
    def self.iscsid
      @@iscsid ||= nil
    end

    def self.iscsid=(pid)
      @@iscsid = pid
    end

    def stop_iscsid
      return unless Iscsid.iscsid
      Process.kill("TERM", Iscsid.iscsid)
      Process.kill("KILL", Iscsid.iscsid)
      Process.detach .iscsid
    end

    def iscsid_running? 
      Process.kill(0, Iscsid.iscsid)
      true
    rescue
      false
    end

    def start_iscsid(startup: false)
      unless startup
        return unless vol_name
      end
      return if Iscsid.iscsid
      return if iscsid_running? 

      Iscsid.iscsid = POSIX::Spawn::spawn('/bb/bin/iscsid -f',
                                          :out=>["/tmp/iscsid.out.log", "w"],
                                          :err=>["/tmp/iscsid.err.log", "w"])

      raise "Unable to start iscsid" unless Iscsid.iscsid
    end
  end
end
