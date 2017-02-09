# Copyright (c) 2015-2017, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

module Helpers
  module Profile
    def profile_env
      env = { 
        "BLOCKBRIDGE_API_KEY"        => system_access_token,
        "BLOCKBRIDGE_API_HOST"       => api_host,
        "BLOCKBRIDGE_API_URL"        => api_url,
      }
    end

    def profile_cmd_exec(cmd, parse_res = true)
      res = cmd_exec_raw(cmd, profile_env)
      if parse_res
        MultiJson.load(res.chomp, symbolize_keys: true)
      end
    end

    def profile_ref_prefix
      "docker-volumeprofile-"
    end

    def profile_ref_name
      "#{profile_ref_prefix}#{profile_name}"
    end

    def profile_create
      logger.info "#{vol_name} profile creating..."
      data = Hash.new.tap do |h|
        h[:name] = params[:name]
        vol_param_keys.each do |p|
          h[p] = params[p] if params[p]
        end
      end
      cmd = "bb -k xmd create --ref #{profile_ref_name} --json 'profile=#{MultiJson.dump(data)}' --process 'puts MultiJson.dump(data.map { |d| d[:data][:profile] })'"
      res = profile_cmd_exec(cmd)
      logger.info "#{vol_name} profile created"
      res
    end

    def profile_remove
      logger.info "#{vol_name} profile removing..."
      cmd = "bb -k xmd remove --ref #{profile_ref_name}"
      profile_cmd_exec(cmd, false)
      logger.info "#{vol_name} profile removed"
    end

    def profile_info(name = nil)
      if name.nil?
        select = "|d| d[:ref].include?(\"#{profile_ref_prefix}\")"
      else
        select = "|d| d[:ref] == \"#{profile_ref_prefix}#{name}\""
      end
      cmd = "bb -k xmd info --process 'puts MultiJson.dump(data.select { #{select} }.map { |d| d[:data][:profile] })'"
      info = profile_cmd_exec(cmd)
      info
    end
  end
end
