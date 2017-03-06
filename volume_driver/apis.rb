# Copyright (c) 2015-2017, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

require 'require_all'

module API; end

class TransportType < Grape::Validations::Base
  def validate_param!(attr_name, params)
    unless params[attr_name] =~ /tls|insecure/
      fail Grape::Exceptions::Validation,
        params: [@scope.full_name(attr_name)],
        message: "Must be one of 'tls', 'insecure'"
    end
  end
end

# Import support APIs
require_rel 'apis/*.rb'

# Top-level volume driver api endpoint
class API::VolumeDriver < Grape::API
  format :json
  default_format :json

  rescue_from Grape::Exceptions::ValidationErrors do |e|
    env.logger.info e.message.chomp.squeeze("\n")
    error!({ Error: e.message, validation_failures: e }, 400)
  end

  rescue_from Blockbridge::NotFound do |e|
    error!({ Error: e.message }, 400)
  end

  rescue_from Blockbridge::Conflict do |e|
    error!({ Error: e.message }, 400)
  end

  rescue_from Blockbridge::ValidationError do |e|
    error!({ Error: e.message}, 400)
  end

  rescue_from Blockbridge::CommandError do |e|
    msg = e.message.chomp.squeeze("\n")
    msg.each_line do |m| env.logger.error(m.chomp) end
    error!({ Error: e.message }, 400)
  end

  rescue_from Blockbridge::ResourcesUnavailable do |e|
    env.logger.info e.message.chomp.squeeze("\n")
    error!({ Error: e.message }, 400)
  end

  rescue_from Excon do |e|
    env.logger.info e.message.chomp.squeeze("\n")
    error!({ Error: e.message }, 400)
  end

  rescue_from Blockbridge::VolumeInuse do |e|
    error!({ Error: e.message }, 400)
  end

  rescue_from :all do |e|
    msg = e.message.chomp.squeeze("\n")
    msg.each_line do |m| env.logger.error(m.chomp) end
    e.backtrace.each do |b| env.logger.error(b) end
    error!(Error: msg)
  end

  before do
    header['Access-Control-Allow-Origin'] = '*'
    header['Access-Control-Request-Method'] = '*'
  end

  helpers ::Helpers

  mount API::Volume
  mount API::Profile
  mount API::Backup
  mount API::DockerPlugin

  route :any, '*path' do
    error!({ Error: 'route not found' }, 404)
  end
end
