# Copyright (c) 2015-2016, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

module Helpers
  module Volume
    def volume_env
      @volume_env ||=
        begin
          env = {
            "BB_MANUAL_MODE"             => "1",
            "LABEL"                      => vol_name,
            "BLOCKBRIDGE_VOLUME_NAME"    => vol_name,
            "BLOCKBRIDGE_VOLUME_REF"     => volume_ref_name,
            "BLOCKBRIDGE_CACHE_REF"      => vol_cache_ref,
            "BLOCKBRIDGE_VOLUME_PARAMS"  => MultiJson.dump(volume_params),
            "BLOCKBRIDGE_VOLUME_TYPE"    => volume_type,
            "BLOCKBRIDGE_VOLUME_PATH"    => vol_path,
            "BLOCKBRIDGE_MOUNT_PATH"     => mnt_path,
            "BLOCKBRIDGE_MODULES_EXPORT" => "1",
            "BLOCKBRIDGE_API_KEY"        => api_token,
            "BLOCKBRIDGE_API_HOST"       => api_host,
            "BLOCKBRIDGE_API_URL"        => api_url,
            "BLOCKBRIDGE_API_SU"         => volume_user,
          }

          # set volume params in environment
          vol_param_keys.each do |p|
            env[p.to_s.upcase] = volume_params[p].to_s if volume_params[p]
          end

          env
        end
    end

    def volume_cmd_exec(cmd)
      cmd_exec(cmd, volume_env)
    end

    def vol_param_keys
      [
        :type,
        :user,
        :capacity,
        :attributes,
        :iops,
        :clone_basis,
        :snapshot_tag,
        :snapshot_interval_hours,
        :snapshot_interval_history
      ]
    end

    def volume_ref_prefix
      "docker-volume-"
    end

    def volume_ref_name
      "#{volume_ref_prefix}#{vol_name}"
    end

    def volume_user
      @volume_user ||=
        begin
          raise Blockbridge::NotFound, "No volume user found; specify user or volume profile" if volume_params[:user].nil?
          cmd_exec("bb -k user info --user #{volume_params[:user]} -X login -X serial --tabular", profile_env)
          volume_params[:user]
        end
    end

    def volume_type
      @volume_type ||=
        begin
          raise Blockbridge::NotFound, "No volume type found; specify volume type or volume profile" if volume_params[:type].nil?
          volume_params[:type]
        end
    end

    def volume_profile
      @volume_profile ||=
        begin
          name = params_profile || 'default'
          profile = profile_info(name).first
          raise "no profile found" if profile.nil?
          logger.info "#{vol_name} using volume profile for #{name}: #{profile}"
          profile
        end
    rescue => e
      raise Blockbridge::NotFound, "Volume profile not specified and no default profile found: #{e.message}" if params_profile.nil?
      raise Blockbridge::NotFound, "Volume profile not found: #{params_profile}: #{e.message}"
    end

    def volume_params_find
      opts = params_opts
      if opts && params_type
        h = Hash.new.tap do |h|
          vol_param_keys.each do |p|
            h[p] = opts[p] if opts.has_key?(p)
          end
          h[:type] = params_type
        end
        logger.info "#{vol_name} using volume info from options: #{h}"
        h
      elsif volume_def
        logger.info "#{vol_name} using volume info from existing volume #{vol_name}: #{volume_def}"
        volume_def
      elsif env_file
        logger.info "#{vol_name} using volume info from environment file #{env_file}: #{env_file_params}"
        env_file_params
      elsif volume_profile
        profile = volume_profile.reject { |k, v| k == :name }
        logger.info "#{vol_name} using volume info from profile #{volume_profile[:name]}: #{profile}"
        profile
      elsif env_file_default
        logger.info "#{vol_name} using volume info from environment file #{env_file_default}: #{env_file_default_params}"
        env_file_default_params
      else
        {}
      end
    end

    def volume_params
      return if vol_cache_enabled?(vol_name)
      @volume_params ||=
        begin
          p = volume_params_find
          p[:name] = vol_name if p
          p
        end
    end

    def volume_check_params
      return if vol_name.nil? && params_profile.nil?
      raise Blockbridge::NotFound, "No volume profile found matching #{params_profile}" if params_profile && volume_profile.nil?
      raise Blockbridge::NotFound, "No volume parameters specified and unable to find profile or env file" if volume_params.nil?
    end

    def volume_def
      @volume_def ||= volume_info.first
    end

    def volume_hosts(xmd)
      xmd[:tags].select { |t| t.include? 'docker-host' }.map { |t| t.gsub('docker-host:', '') }.join(',')
    end

    def volume_info_map(info)
      info.map do |xmd|
        v = xmd[:data][:volume]
        v[:hosts] = volume_hosts(xmd) if volume_hosts(xmd).length > 0
        v[:deleted] = xmd[:data][:deleted] if xmd[:data][:deleted]
        v
      end
    end

    def volume_mapped_name(volume)
      name  = volume[:name]
      name += " [ #{volume[:hosts]} ]" if volume[:hosts]
      name
    end

    def volume_info
      if vol_name.nil?
        select = "|d| d[:ref].include?(\"#{volume_ref_prefix}\")"
      else
        select = "|d| d[:ref] == \"#{volume_ref_prefix}#{vol_name}\""
      end
      cmd = "bb -k xmd info --process 'puts MultiJson.dump(data.select { #{select} })'"
      info = profile_cmd_exec(cmd)
      volume_info_map(info)
    end

    def volume_lookup
      info = volume_info
      raise Blockbridge::NotFound, "No volume named #{vol_name} found" if info.length == 0
      info
    end

    def volume_lookup_one
      volume_lookup.first
    end

    def mnt_path_map(name = nil)
      return "" if name.nil?
      return "" unless mount_needed?(name)
      mnt_path(name)
    end

    def volume_list
      volume_info.select { |v| !v.has_key?(:deleted) }.map do |v|
        {
          Name:       v[:name],
          Mountpoint: mnt_path(v[:name])
        }
      end
    end

    def volume_get
      if vol_cache_enabled?(vol_name)
        v = vol_cache_get(vol_name)
        {
          Name:       v[:name],
          Mountpoint: mnt_path_map(v[:name])
        }
      elsif (v = volume_lookup.first)
        {
          Name:       v[:name],
          Mountpoint: mnt_path_map(v[:name])
        }
      end
    end

    def volume_create
      volume_check_params
      logger.info "#{vol_name} creating..."
      if volume_type == "autoclone"
        volume_clone
      else
        volume_provision
      end
      logger.info "#{vol_name} created"
    rescue
      volume_cmd_exec("bb_remove") rescue nil
      raise
    end

    def volume_clone
      logger.info "#{vol_name} cloning..."
      volume_cmd_exec("bb_clone")
      logger.info "#{vol_name} cloned"
    end

    def volume_bb_remove
      logger.info "#{vol_name} removing..."
      if volume_type == "autoclone"
        volume_cmd_exec("bb_remove", "-c")
      else
        volume_cmd_exec("bb_remove")
      end
      logger.info "#{vol_name} removed"
    end

    def volume_start_async_remove
      params = {
        mode: 'patch',
        data: [ { op: 'add', path: '/deleted', value: Time.now.tv_sec } ]
      }
      bbapi(volume_user).xmd.update(volume_ref_name, params)
      vol_cache_add(vol_name, volume_params.merge({deleted: true, env: volume_env}), true)
    end

    def volume_remove(opts = {})
      return if vol_cache_enabled?(vol_name)
      vol = volume_lookup_one
      if bb_is_attached(vol[:user], vol[:name])
        raise Blockbridge::VolumeInuse, "Volume cannot be removed; it is still in-use" 
      end
      if opts[:async]
        volume_start_async_remove
      else
        volume_bb_remove
      end
    end

    def volume_provision
      logger.info "#{vol_name} provisioning if needed..."
      volume_cmd_exec("bb_provision")
      logger.info "#{vol_name} provisioned"
    rescue Blockbridge::CommandError => e
      if e.message.include? "Query returned no results"
        cmd_res_dump(e.message)
        raise Blockbridge::ResourcesUnavailable, 'No resources available with requested provisioning parameters'
      end
      raise
    end

    def volume_mkfs
      begin
        volume_cmd_exec("bb_mkfs")
      rescue
        logger.info "#{vol_name} formatting..."
        volume_cmd_exec("bb_attach")
        volume_cmd_exec("bb_mkfs")
        logger.info "#{vol_name} formatted"
      ensure
        volume_cmd_exec("bb_detach")
      end
    end

    def volume_mount
      mount_ref
      logger.info "#{vol_name} mounting if needed..."
      volume_cmd_exec("bb_attach")
      volume_cmd_exec("bb_mkfs")
      volume_cmd_exec("bb_mount")
      logger.info "#{vol_name} mounted"
    end

    def volume_unmount
      mount_unref
      return if mount_needed?
      logger.info "#{vol_name} unmounting..."
      volume_cmd_exec("bb_unmount")
      volume_cmd_exec("bb_detach")
      logger.info "#{vol_name} unmounted"
    end
  end
end
