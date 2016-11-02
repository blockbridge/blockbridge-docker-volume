# Copyright (c) 2015-2016, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

module Helpers
  module Exec
    def as_root_shell(args)
      case args
      when Array
        as_root_user('bash', '-c', "#{args.shelljoin}")
      when String
        as_root_user('bash', '-c', args)
      else
        raise PermanentError, "exec args of wrong type '#{args.class}'"
      end
    end

    def as_root_user(*args)
      root? ? runcmd(*args) : runcmd('sudo', '-u', 'root', *args)
    end

    def as_block_user(*args)
      as_non_root_user('block', *args)
    end

    def as_setup_user(*args)
      as_non_root_user('setup', *args)
    end

    def as_non_root_user(user, *args)
      if root?
        runcmd('su', user, '--login', '-s', '/bin/sh', '-c', args.shelljoin)
      else
        if Etc.getpwuid(Process.uid).name == user
          runcmd(*args)
        else
          runcmd('sudo', '-u', user, *args)
        end
      end
    end

    def runcmd(*args)
      output = IO.popen([*args, :err => [:child, :out]]) do |io|
        io.read
      end

      unless $?.success?
        raise Blockbridge::CommandError, "Failed to run command '#{args.join(' ')}', status=#{$?}, "\
              "output=#{output}"
      end

      output
    end
  end
end
