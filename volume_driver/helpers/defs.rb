# Copyright (c) 2015-2017, Blockbridge Networks LLC.  All rights reserved.
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

    def mount_ref_id
      @mount_ref_id ||= params[:ID]
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

    def vol_path(name = nil)
      name = vol_name if name.nil?
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

    def api_host_url
      "https://#{Resolv.getaddress(api_host)}/api"
    end

    def api_host_internal_url
      "https://#{Resolv.getaddress(api_host)}:9999/api"
    end

    def api_url(access_token = nil)
      if access_token && access_token != system_access_token
        api_host_url
      elsif system_access_token != access_token_default
        api_host_url
      else
        api_host_internal_url
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

    def params_parse_s3(str)
      return unless str
      if str.include? '/'
        str.split('/').first
      end
    end

    def params_backup_fields
      [
        :backup_name,
        :from_backup,
        :backup,
      ]
    end

    def params_obj_store
      return params_opts[:s3] if params_opts[:s3]
      s3 = nil
      params_backup_fields.each do |fld|
        s3 = params_parse_s3 params_opts[fld]
        break if s3
      end
      s3
    end

    def params_parse_backup(str)
      return unless str
      str.gsub(/^.*?\//, '')
    end

    def params_backup
      backup = nil
      params_backup_fields.each do |fld|
        backup = params_parse_backup params_opts[fld]
        break if backup
      end
      backup
    end
  end
end
