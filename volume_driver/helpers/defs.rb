# Copyright (c) 2015-2016, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

module Helpers
  module Defs
    def blockbridge_root
      ENV['BLOCKBRIDGE_ROOT'] || '/bb'
    end

    def volumes_root
      @volumes_root ||= File.join(blockbridge_root, 'volumes')
    end

    def vol_name
      @vol_name ||= parse_params_name || params[:Name] || params[:name]
    end

    def profile_name
      @profile_name ||= params[:profile] || params[:name]
    end

    def env_name
      @env_name ||= vol_name
    end

    def env_path
      File.join(blockbridge_root, 'env', env_name)
    end

    def env_path_default
      File.join(blockbridge_root, 'env', 'DEFAULT')
    end

    def env_file
      @env_file ||=
        begin
          env_path if File.exist? env_path
        end
    end

    def env_file_params
      return if env_file.nil?
      @env_file_params ||=
        begin
          params = {}
          File.foreach(env_file).map do |line|
            line.chomp!
            next if line.match('^#')
            k, v = line.split('=')
            params[k.downcase.to_sym] = v
          end
          params if params.length > 0
        end
    end

    def env_file_default
      @env_file_default ||=
        begin
          env_path_default if File.exist? env_path_default
        end
    end

    def env_file_default_params
      return if env_file_default.nil?
      @env_file_default_params ||=
        begin
          params = {}
          File.foreach(env_file_default).map do |line|
            line.chomp!
            next if line.match('^#')
            k, v = line.split('=')
            params[k.downcase.to_sym] = v
          end
          params if params.length > 0
        end
    end

    def mnt_path(name = vol_name)
      File.join(blockbridge_root, 'mnt', name)
    end

    def vol_path(name = vol_name)
      return "" if name.nil?
      File.join(volumes_root, name)
    end

    def access_token_default
      "--unset-default--"
    end

    def system_access_token
      Blockbridge::Config.access_token || ENV['BLOCKBRIDGE_API_KEY'] || access_token_default
    end

    def api_host
      Blockbridge::Config.api_host || ENV['BLOCKBRIDGE_API_HOST']
    end

    def api_url
      if system_access_token != access_token_default
        "https://#{api_host}/api"
      else
        "https://#{Resolv.getaddress(api_host)}:9999/api"
      end
    end

    def params_profile
      return params[:profile] if params[:profile]
      return params['Opts']['profile'] unless params['Opts'].nil?
    end

    def params_opts
      return params['Opts'].deep_symbolize_keys if params['Opts']
      return params.deep_symbolize_keys
    end

    def params_type
      # return type if specified as parameter
      return params[:type] unless params[:type].nil?
      return params['Opts']['type'] unless params['Opts'].nil? || params['Opts']['type'].nil?

      # set default type. But not if profile. And only if other params set
      return if params_profile
      return 'autovol' unless ((vol_param_keys - params_opts.keys) == vol_param_keys)
    end
  end
end
