# Copyright (c) 2015, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

require 'tempfile'
require 'fileutils'
require 'socket'
require 'em-synchrony'
require 'posix/spawn'
require 'volume'
require 'docker_api'
require 'refs'
require 'pp'

module Blockbridge
  module Helpers
    include Blockbridge::Volume
    include Blockbridge::Docker
    include Blockbridge::Refs

    def logger
      env.logger
    end

    def volumes_root
      @volumes_root ||= File.join(ENV['BLOCKBRIDGE_ROOT'], 'volumes')
    end

    def vol_name
      @vol_name ||= params[:Name]
    end

    def env_name
      @env_name ||= vol_name
    end

    def env_path
      File.join(ENV['BLOCKBRIDGE_ROOT'], 'env', env_name)
    end

    def env_path_default
      File.join(ENV['BLOCKBRIDGE_ROOT'], 'env', 'DEFAULT')
    end

    def env_file
      @env_file ||=
        begin
          if File.exist?(env_path)
            env_path
          elsif File.exist?(env_path_default)
            env_path_default
          end
        end
    end

    def mnt_path
      File.join(ENV['BLOCKBRIDGE_ROOT'], 'mnt', vol_name)
    end

    def vol_path
      File.join(volumes_root, vol_name)
    end

    def vol_ref_path
      File.join(vol_path, 'ref')
    end

    def vol_ref_file
      File.join(vol_ref_path, 'vol')
    end

    def mnt_ref_file
      File.join(vol_ref_path, 'mnt')
    end

    def api_token
      ENV['BLOCKBRIDGE_API_KEY']
    end

    def api_host
      ENV['BLOCKBRIDGE_API_HOST']
    end

    def vol_type
      File.foreach(env_file).map do |line|
        line.chomp!
        next if line.match('^#')
        k, v = line.split('=')
        if k == "TYPE"
          return v.downcase
        end
      end

      raise "TYPE not found in #{env_file}"
    end

    def vol_user
      File.foreach(env_file).map do |line|
        line.chomp!
        next if line.match('^#')
        k, v = line.split('=')
        if k == "USER"
          return v
        end
      end

      raise "USER not found in #{env_file}"
    end

    def driver_init
      unref_all
    end

    def check_name
      return unless params[:Name]
      return if env_file
      raise "Volume '#{params[:Name]}' is not configured in #{env_file}; no '/bb/env/DEFAULT' configuration found."
    end

    def self.iscsid
      @@iscsid ||= nil
    end

    def self.iscsid=(pid)
      @@iscsid = pid
    end

    def stop_iscsid
      return unless Helpers.iscsid
      Process.kill("TERM", Helpers.iscsid)
      Process.kill("KILL", Helpers.iscsid)
      Process.detach Helpers.iscsid
    end

    def iscsid_running? 
      Process.kill(0, Helpers.iscsid)
      true
    rescue
      false
    end

    def start_iscsid
      return unless params[:Name]
      return if Helpers.iscsid
      return if iscsid_running? 

      Helpers.iscsid = POSIX::Spawn::spawn('/bb/bin/iscsid -f',
                                           :out=>["/tmp/iscsid.out.log", "w"],
                                           :err=>["/tmp/iscsid.err.log", "w"])

      raise "Unable to start iscsid" unless Helpers.iscsid
    end

    def cmd_exec_multi(cmds)
      multi = EventMachine::Synchrony::Multi.new
      cmds.each_with_index do |cmd, idx|
        multi.add idx, cmd_exec_async(*cmd)
      end
      res = multi.perform
      pp res
    end

    def cmd_exec_async(*cmd)
      res = EM::DefaultDeferrable.new
      cb = proc {|result|
        res.succeed(result)
      }
      EM.defer(nil, cb) do
        child = POSIX::Spawn::Child.build(volume_env, *cmd, :timeout => 60)
        begin
          child.exec!
          {
            sts: child.status.exitstatus,
            err: child.err || "",
            out: child.out || "",
          }
        rescue => e
          {
            sts: 1,
            err: "#{cmd.to_s}: #{e.message}: #{child.err || ""}",
            out: child.out || "",
          }
        end
      end
      res 
    end

    def cmd_exec(*cmd)
      res = EM::Synchrony.sync cmd_exec_async(*cmd)
      if res[:sts] != 0
        raise "#{vol_name} #{cmd.first} failed: #{res[:out] + res[:err]}"
      end
      res[:out].split('\n').each do |m|
        msg = m.chomp.squeeze("\n")
        msg.each_line do |m| logger.info "#{vol_name} #{m.chomp}" end
      end
    end

    def self.locks
      @@locks ||= {}
    end

    def synchronize(&blk)
      lock = Helpers.locks[vol_name] ||= {
        mutex: EM::Synchrony::Thread::Mutex.new,
        ref:   0
      }
      lock[:ref] += 1
      lock[:mutex].synchronize(&blk)
      lock[:ref] -= 1
      Helpers.locks.delete(vol_name) if lock[:ref] == 0
    end
  end
end
