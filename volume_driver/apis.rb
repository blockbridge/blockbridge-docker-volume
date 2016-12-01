# Copyright (c) 2015-2016, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

require 'require_all'

module API; end

# Type validators
class VolumeType < Grape::Validations::Base
  def validate_autovol(params)
    unless params[:capacity] &&
           params[:user]
      fail Grape::Exceptions::Validation,
        params:  [ @scope.full_name(:user),
                   @scope.full_name(:capacity) ],
        message: 'all required parameters must be specified for autovol volumes'
    end
  end

  def validate_autoclone(params)
    unless params[:user] &&
           params[:clone_basis] &&
           params[:snapshot_tag]
      fail Grape::Exceptions::Validation,
        params:  [ @scope.full_name(:user),
                   @scope.full_name(:clone_basis),
                   @scope.full_name(:snapshot_tag) ],
        message: 'all required parameters for autoclone volumes must be specified'
    end

    if params[:attributes]
      fail Grape::Exceptions::Validation,
        params:  [ @scope.full_name(:attributes) ],
        message: 'the specified parameter is not valid for autoclone volumes'
    end

    if params[:iops]
      fail Grape::Exceptions::Validation,
        params:  [ @scope.full_name(:iops) ],
        message: 'the specified parameter is not valid for autoclone volumes'
    end
  end

  def validate_snappy(params)
    unless params[:user] &&
           params[:capacity] &&
           params[:snapshot_interval_hours] &&
           params[:snapshot_interval_history]
      fail Grape::Exceptions::Validation,
        params:  [ @scope.full_name(:user),
                   @scope.full_name(:capacity),
                   @scope.full_name(:snapshot_interval_hours),
                   @scope.full_name(:snapshot_interval_history) ],
        message: 'all required parameters for snappy volumes must be specified'
    end
  end

  def validate_param!(attr_name, params)
    case params[attr_name]
    when 'autovol'
      validate_autovol(params)
    when 'autoclone'
      validate_autoclone(params)
    when 'snappy'
      validate_snappy(params)
    else
      fail Grape::Exceptions::Validation,
        params: [@scope.full_name(attr_name)],
        message: "Must be one of 'autovol', 'autoclone', 'snappy'"
    end

    if params[:attributes]
      params[:attributes].split(' ').each do |a|
        if !a.start_with?("+", "-")
          fail Grape::Exceptions::Validation,
            params:  [ @scope.full_name(:attributes) ],
            message: 'attributes must start with "+" to include or "-" to exclude (eg: +ssd -production)'
        end
      end
    end
  end
end

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

  rescue_from Blockbridge::CommandError do |e|
    msg = e.message.chomp.squeeze("\n")
    msg.each_line do |m| env.logger.error(m.chomp) end
    e.backtrace.each do |b| env.logger.error(b) end
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
