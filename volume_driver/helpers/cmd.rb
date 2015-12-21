# Copyright (c) 2015-2016, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

module Helpers
  module Cmd
    def cmd_exec_multi(cmds)
      multi = EventMachine::Synchrony::Multi.new
      cmds.each_with_index do |cmd, idx|
        multi.add idx, cmd_exec_async(*cmd)
      end
      res = multi.perform
      pp res
    end

    def cmd_exec_async(*cmd, cmd_env)
      res = EM::DefaultDeferrable.new
      cb = proc {|result|
        res.succeed(result)
      }
      EM.defer(nil, cb) do
        child = POSIX::Spawn::Child.build(cmd_env, *cmd, :timeout => 60)
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

    def cmd_exec_raw(*cmd, cmd_env)
      res = EM::Synchrony.sync cmd_exec_async(*cmd, cmd_env)
      if res[:sts] != 0
        raise Blockbridge::CommandError, "#{cmd.first} failed: #{res[:out] + res[:err]}"
      end
      res[:out]
    end

    def cmd_res_dump(res)
      return if res.nil?
      res.split('\n').each do |m|
        msg = m.chomp.squeeze("\n")
        msg.each_line do |m| logger.info "#{vol_name} #{m.chomp}" end
      end
    end

    def cmd_exec(*cmd, cmd_env)
      res = cmd_exec_raw(*cmd, cmd_env)
      cmd_res_dump(res)
    end
  end
end
