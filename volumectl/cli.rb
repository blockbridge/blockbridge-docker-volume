# Copyright (c) 2015-2017, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

require 'blockbridge/util/tabular'
require 'facets/string/word_wrap'
require 'volumectl/view'
require 'volume_driver/helpers/errors'
require 'securerandom'

class CliMain
  class << self
    attr_accessor :last_argv
    attr_accessor :last_cmd_instance
    attr_accessor :last_exit_status
    attr_accessor :cmd_name
    attr_accessor :argv_override
  end

  attr_reader :cmd_instance
  attr_reader :exit_status
  attr_reader :root_cmd
  attr_reader :opts

  EXIT_SUCCESS  = 0
  EXIT_FAILURE  = 1

  ExecStatus = Struct.new(:command, :exitstatus, :exception) do
    def success?
      exitstatus == 0
    end
  end

  def initialize(root_cmd, argv, stdin=STDIN, stdout=STDOUT,
                 stderr=STDERR, kernel=Kernel)
    @cmd_name = nil
    @root_cmd = root_cmd
    @argv = argv
    @stdin, @stdout, @stderr, @kernel = stdin, stdout, stderr, kernel
  end

  def cmd_name
    @cmd_name || self.class.cmd_name || File.basename($0)
  end

  def cmd_name=(name)
    @cmd_name = name
  end

  def argv
    self.class.argv_override || @argv
  end

  def execute!
    # redirect in/out/err streams
    $stderr = @stderr
    $stdin  = @stdin
    $stdout = @stdout
    @opts = {
      verbose:  verbose?,
      debug:    debug?,
    }

    begin
      exc      = nil
      root_obj = root_cmd.new(cmd_name, opts)
      root_obj.parse(argv)

      # assume success if no exception was raised -- also return the
      # command instance object.
      @cmd_instance = root_obj.execute
      @exit_status = 0

    rescue StandardError, Interrupt => exc
      # exceptions generated by clamp before 'execute' is called don't get
      # command_instance injected into them. maybe clamp's 'command' is there?
      # if not, there's nothing we can do, but it probably doesn't matter since
      # the command was never executed anyway. (and thus, there probably never
      # was an instance in the first place.)
      @cmd_instance =
        if exc.respond_to?(:command_instance) && exc.command_instance
          exc.command_instance
        elsif exc.respond_to?(:command) && exc.command
          exc.command
        else
          nil
        end

      @exit_status = handle_exception(exc)

    ensure
      # restore in/out/err streams
      $stderr = STDERR
      $stdin  = STDIN
      $stdout = STDOUT
    end

    self.class.last_argv         = argv
    self.class.last_cmd_instance = cmd_instance
    self.class.last_exit_status  = exit_status

    @kernel.exit(exit_status || 0)

    # for interactive/script mode or for unit-testing, return the exec
    # status as an object.
    ExecStatus.new(cmd_instance, exit_status, exc)
  end

  private

  def opt_or_env(opt, env, default = nil)
    if (idx = argv.index(opt) && argv[idx+1])
      argv[idx+1]
    elsif ENV.key? env
      ENV[env]
    else
      default
    end
  end

  def error_format
    return 'machine' if cmd_instance && cmd_instance.machine?
  end

  def verbose?
    argv.include?('--verbose') || (cmd_instance && cmd_instance.verbose?)
  end

  def debug?
    argv.include?('--debug') || (cmd_instance && cmd_instance.debug?)
  end

  def handle_exception(e)
    raise unless cmd_instance

    opts[:cmd] = cmd_instance

    # format the exception according to the configured error format
    exc_view = Blockbridge::View.new
    name = cmd_instance.invocation_path.sub(/^bb[^ ]* /, '').to_s.gsub(/[ -]/, '_')[/([^_]+)/,1]

    case error_format
    when 'machine'
      # machine output dumps the exception view to stdout
      name = "#{name}_exception_machine"
      $stdout.print exc_view.render(:exception_machine, e, opts)
    else
      # human output dumps the exception view to stderr
      name = "#{name}_exception_human"
      $stderr.print exc_view.render(name, e, opts)
    end

    # map to exit status
    case e
    when Blockbridge::RuntimeSuccess, Clamp::HelpWanted
      EXIT_SUCCESS
    else
      # optionally display the exception backtrace
      raise if debug?

      EXIT_FAILURE
    end
  end
end
