# Copyright (c) 2015-2017, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

require 'require_all'

require 'tempfile'
require 'fileutils'
require 'socket'
require 'em-synchrony'
require 'active_support/core_ext/hash'
require 'pp'

require_rel 'helpers/*.rb'

# Helpers
module Helpers
  include Helpers::Params
  include Helpers::Volume
  include Helpers::Profile
  include Helpers::Backup
  include Helpers::DockerApi
  include Helpers::BlockbridgeApi
  include Helpers::Iscsid
  include Helpers::Sync
  include Helpers::Cmd
  include Helpers::Defs
  include Helpers::Refs
  include Helpers::Cache
  include EventMachine::Synchrony

  def logger
    env.logger
  end

  def driver_init
    unref_all
  end
end
