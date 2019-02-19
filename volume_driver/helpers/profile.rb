# Copyright (c) 2015-2017, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

module Helpers
  module Profile
    def profile_ref_prefix
      "docker-volumeprofile-"
    end

    def profile_ref_name
      "#{profile_ref_prefix}#{profile_name}"
    end

    def profile_create
      logger.info "#{vol_name} profile creating..."

      # ensure user exists
      unless user_access_token
        user = bbapi(nil, nil).user_profile.list(login: params[:user])&.first
        raise Blockbridge::NotFound unless user
      end

      # create profile
      data = Hash.new.tap do |h|
        h[:name] = params[:name]
        vol_param_keys.each do |p|
          h[p] = params[p] if params[p]
        end
      end
      res = bbapi(nil, nil).xmd.create(ref: profile_ref_name, data: { profile: data })
      logger.info "#{vol_name} profile created"
      res&.dig('data', 'profile')
    rescue Excon::Errors::NotFound, Excon::Errors::Gone, Blockbridge::NotFound, Blockbridge::Api::NotFoundError
      raise Blockbridge::NotFound, "User #{params[:user]} does not exist."
    rescue Blockbridge::Api::ConflictError
      raise Blockbridge::Conflict, "Profile #{params[:name]} already exists."
    end

    def profile_remove
      logger.info "#{vol_name} profile removing..."
      symbolize bbapi(nil, nil).xmd.remove(profile_ref_name)
      logger.info "#{vol_name} profile removed"
    rescue Excon::Errors::NotFound, Excon::Errors::Gone, Blockbridge::NotFound, Blockbridge::Api::NotFoundError
      raise Blockbridge::NotFound, "Profile #{params[:name]} not found."
    end

    def profile_info(name = nil)
      if name.nil?
        symbolize bbapi(nil, nil).xmd.list.select { |x| x[:ref].include? profile_ref_prefix }.map { |x| x.dig('data', 'profile') }
      else
        symbolize [ bbapi(nil, nil).xmd.info("#{profile_ref_prefix}#{name}")&.dig('data', 'profile') ]
      end
    rescue Excon::Errors::NotFound, Excon::Errors::Gone, Blockbridge::NotFound, Blockbridge::Api::NotFoundError
      raise Blockbridge::NotFound, "Profile #{name} not found."
    end
  end
end
