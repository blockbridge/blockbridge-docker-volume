# Copyright (c) 2015-2017, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

require 'bundler/setup'

require 'goliath'
require 'grape'

require_relative 'volume_driver/version'
require_relative 'volume_driver/helpers'
require_relative 'volume_driver/apis'
require_relative 'volume_driver/plugins'

# do NOT use Goliath's at_exit auto-run handler.
Goliath.run_app_on_exit = false

class VolumeDriver
  class Server < Goliath::API
    use Goliath::Rack::Render # auto-negotiate response format
    use Goliath::Rack::Params # parse & merge query and body parameters

    plugin Blockbridge::Startup
    plugin Blockbridge::Config
    plugin Blockbridge::VolumeCacheMonitor
    plugin Blockbridge::VolumeHostinfo

    # process api call
    def response(env)
      API::VolumeDriver.call(env)
    end
  end

  Goliath::Request.log_block = proc do |env, response, elapsed_time|
    env.logger.debug do
      full_uri = env['PATH_INFO']
      if (query_string = env['QUERY_STRING']) && !query_string.empty?
        full_uri += "?" + query_string
      end

      str = '- '
      if env['api.request.body']
        name = env['api.request.body']['Name'].to_s
        str = name.empty? ? '- ' : "#{name} "
      end
      str.concat "#{env['REMOTE_USER'] || '-'} " \
      "\"#{env['REQUEST_METHOD']} #{full_uri} #{env['HTTP_VERSION']}\" " \
      "#{response.status} " \
      "#{response.headers['Content-Length'] || '-'} " \
      "[#{"%.2f" % elapsed_time}ms]"
    end
  end

  class Logger < Log4r::Logger
    def initialize(name)
      super(name)
      if logger_timestamp == "1"
        pattern = "%d %-7l %c -- %m\n"
        datefmt = "%Y-%m-%dT%H:%M:%S.%3N"
        format  = Log4r::PatternFormatter.new(pattern: pattern, date_pattern: datefmt)
        stdout  = Log4r::StdoutOutputter.new('console', :formatter => format)
      else
        pattern = "%-7l %c -- %m\n"
        format  = Log4r::PatternFormatter.new(pattern: pattern)
        stdout  = Log4r::StdoutOutputter.new('console', :formatter => format)
      end
      add(stdout)
    end

    def logger_timestamp
      ENV['BLOCKBRIDGE_LOGGER_TIMESTAMP'] || "1"
    end
  end

  class Runner < Goliath::Runner
    def initialize
      super(ARGV, nil)
      @api    = VolumeDriver::Server.new
      @app    = Goliath::Rack::Builder.build(VolumeDriver::Server, api)
      @logger = VolumeDriver::Logger.new('blockbridge')
      @logger.info "Blockbridge Volume Driver #{Blockbridge::VolumeDriverVersion::VERSION}"
    end

    def run
      super
      Signal.trap("TERM", "IGNORE")
      Signal.trap("INT", "IGNORE")
    end
  end
end

driver = VolumeDriver::Runner.new()
driver.load_plugins(VolumeDriver::Server.plugins)
driver.run
exit 0
