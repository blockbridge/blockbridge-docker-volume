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
            "BLOCKBRIDGE_HOSTINFO_REF"   => vol_hostinfo_ref,
            "BLOCKBRIDGE_VOLUME_PARAMS"  => volume_params_json,
            "BLOCKBRIDGE_VOLUME_TYPE"    => volume_type,
            "BLOCKBRIDGE_VOLUME_PATH"    => vol_path,
            "BLOCKBRIDGE_MOUNT_PATH"     => mnt_path,
            "BLOCKBRIDGE_MODULES_EXPORT" => "1",
            "BLOCKBRIDGE_API_HOST"       => api_host,
            "BLOCKBRIDGE_API_URL"        => api_url,
          }

          # set volume params in environment
          vol_param_keys.each do |p|
            env[p.to_s.upcase] = volume_params[p].to_s if volume_params[p]
          end

          env
        end
      @volume_env["BLOCKBRIDGE_API_KEY"] = volume_access_token
      @volume_env["BLOCKBRIDGE_API_URL"] = api_url(@volume_env["BLOCKBRIDGE_API_KEY"])
      @volume_env["BLOCKBRIDGE_API_SU"]  = volume_su_user
      @volume_env["BLOCKBRIDGE_HOST_TRANSPORT"] = "--#{volume_params[:transport].downcase}" if volume_params[:transport]
      @volume_env.reject { |k, v| v.nil? }
    end

    def volume_params_json
      MultiJson.dump(volume_params)
    end

    def volume_cmd_exec(cmd, **params)
      cmd_exec(cmd, volume_env.merge(**params))
    end

    def vol_hostinfo_ref(name = nil)
      if name
        "docker-volumehostinfo-#{name}"
      else
        "docker-volumehostinfo-#{vol_name}"
      end
    end

    def vol_param_keys
      [
        :type,
        :user,
        :access_token,
        :transport,
        :capacity,
        :attributes,
        :iops,
        :from_backup,
      ]
    end

    def volume_ref_prefix
      "docker-volume-"
    end

    def volume_ref_name(name = nil)
      if name
        "#{volume_ref_prefix}#{name}"
      else
        "#{volume_ref_prefix}#{vol_name}"
      end
    end

    def volume_user
      return unless defined? params
      @volume_user ||=
        begin
          raise Blockbridge::NotFound, "No volume user found; specify user or volume profile" if volume_params[:user].nil?
          cmd_exec("bb -k user info --user #{volume_params[:user]} -X login -X serial --tabular", profile_env)
          volume_params[:user]
        end
    end

    def volume_type
      return unless defined? params
      @volume_type ||=
        begin
          raise Blockbridge::NotFound, "No volume type found; specify volume type or volume profile" if volume_params[:type].nil?
          volume_params[:type]
        end
    end

    def volume_profile
      return unless defined? params
      @volume_profile ||=
        begin
          name = params_profile || 'default'
          profile = profile_info(name).first
          raise "no profile found" if profile.nil?
          profile
        end
    rescue => e
      raise Blockbridge::NotFound, "Volume profile not found: #{params_profile}: #{e.message}" if params_profile
    end

    def volume_params_opts
      opts = params_opts
      if opts && params_type
        h = Hash.new.tap do |h|
          vol_param_keys.each do |p|
            h[p] = opts[p] if opts.has_key?(p)
          end
          h[:type] = params_type
        end
        h
      end
    end

    def volume_params_find
      if volume_profile
        profile = volume_profile.reject { |k, v| k == :name }
        logger.info "#{vol_name} using volume info from profile #{volume_profile[:name]}: #{profile}"
        profile
      else
        {}
      end
    end

    def volume_params_augment(p)
      p[:name]   = vol_name
      p[:s3]     = params_obj_store if params_obj_store
      p[:backup] = params_backup if params_backup
      p.delete(:backup_name)
      p.delete(:from_backup)
    end

    def volume_params
      return unless defined? params
      return if vol_cache_enabled?(vol_name)
      @volume_params ||=
        begin
          p = volume_def || volume_params_find
          p.merge! volume_params_opts if volume_params_opts
          volume_params_augment p
          logger.info "#{vol_name} using volume options: #{p}" unless volume_def
          p
        end
    end

    def volume_check_params
      return if vol_name.nil? && params_profile.nil?
      raise Blockbridge::NotFound, "No volume profile found matching #{params_profile}" if params_profile && volume_profile.nil?
      raise Blockbridge::NotFound, "No volume parameters specified and no default profile found" if volume_params.nil?
    end

    def volume_def
      return if vol_name.nil?
      @volume_def ||= volume_info.first
    end

    def volume_hosts(xmd)
      xmd[:tags].select { |t| t.include? 'docker-host' }.map { |t| t.gsub('docker-host:', '') }.join(',')
    end

    def volume_info_map(info, raw = false)
      info.map do |xmd|
        next unless (v = xmd[:data][:volume])
        unless raw
          v[:hosts] = volume_hosts(xmd) if volume_hosts(xmd).length > 0
          v[:deleted] = xmd[:data][:deleted] if xmd[:data][:deleted]
          v.delete(:scope_token)
        end
        v
      end
    end

    def volume_mapped_name(volume)
      name  = volume[:name]
      name += " [ #{volume[:hosts]} ]" if volume[:hosts]
      name
    end

    def volume_info(raw = false)
      if vol_name.nil?
        select = "|d| d[:ref].include?(\"#{volume_ref_prefix}\")"
      else
        select = "|d| d[:ref] == \"#{volume_ref_prefix}#{vol_name}\""
      end
      cmd = "bb -k xmd info --process 'puts MultiJson.dump(data.select { #{select} })'"
      info = profile_cmd_exec(cmd)
      volume_info_map(info, raw)
    end

    def volume_lookup(raw = false)
      info = volume_info(raw)
      raise Blockbridge::NotFound, "No volume named #{vol_name} found" if info.length == 0
      info
    end

    def volume_lookup_all
      volume_lookup
    rescue
      []
    end

    def volume_lookup_one(raw = false)
      volume_lookup(raw).first
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
          Name:       params_name || v[:name],
          Mountpoint: mnt_path_map(v[:name])
        }
      elsif (v = volume_lookup.first)
        {
          Name:       params_name || v[:name],
          Mountpoint: mnt_path_map(v[:name])
        }
      end
    end

    def volume_exists?
      bbapi.vdisk.list(label: vol_name).first
    end

    def volume_create
      volume_check_params
      return if volume_exists?
      logger.info "#{vol_name} creating..."
      bb_vss_provision
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

    def volume_scoped
      case env['REQUEST_URI']
      when '/VolumeDriver.Unmount'
        true
      else
        false
      end
    end

    def volume_access_token
      return unless defined? params
      # if otp specified, use session token. Either auth login to create one or use valid one.
      # - if can't SU, then it will fail. RETURN good error here saying can't SU
      #
      # if otp not specified, use user token. If not user token, use system + su
      # - if otp is required by user, it will fail. RETURN GOOD error here saying OTP required.
      #
      # - User has OTP enabled
      # - User has SU disabled
      # - User token should be created with respect OTP
      # - System token should be created with respect OTP
      if volume_scoped && (scope_token = volume_scope_token)
        token = scope_token
      elsif (otp = params_opts[:otp])
        if session_token_valid? otp
          token = get_session_token(otp)
        else
          if volume_params[:access_token]
            # login otp with user access token
            bbapi(nil, volume_params[:access_token], otp)
          else
            # login otp with system token and SU
            bbapi(volume_user, system_access_token, otp)
          end
          token = get_session_token(otp)
        end
      else
        if volume_params[:access_token]
          token = volume_params[:access_token]
        else
          token = system_access_token
        end

        # login to check for otp required
        bbapi(nil, token)
      end
      token
    end

    def volume_su_user
      return if volume_access_token != system_access_token
      volume_user
    end

    def volume_scope_token
      volume = volume_info(true).first
      return volume[:scope_token]
    end

    def volume_start_async_remove
      params = {
        mode: 'patch',
        data: [ { op: 'add', path: '/deleted', value: Time.now.tv_sec } ]
      }
      bbapi(volume_user, volume_access_token).xmd.update(volume_ref_name, params)
      vol_cache_add(vol_name, volume_params.merge({deleted: true, env: volume_env}), true)
    end

    def volume_remove(opts = {})
      return if vol_cache_enabled?(vol_name)
      vol_info = volume_lookup_one(true)
      if bb_get_attached(vol_info[:name], vol_info[:user], vol_info[:scope_token])
        raise Blockbridge::VolumeInuse, "Volume cannot be removed; it is still in-use" 
      end
      if opts[:async]
        volume_start_async_remove
      else
        volume_bb_remove
      end
    end

    def volume_freeze(vol)
      return unless mount_needed?
      cmd = "#{ns_exec_mnt} #{fsfreeze} --freeze #{mnt_path(vol[:name])}"
      volume_cmd_exec(cmd)
    end

    def volume_unfreeze(vol)
      return unless vol && mount_needed?
      cmd = "#{ns_exec_mnt} #{fsfreeze} --unfreeze #{mnt_path(vol[:name])}"
      volume_cmd_exec(cmd)
    end

    def volume_backup
      vol = volume_lookup_one(true)
      volume_freeze(vol)
      bb_backup_vol(vol)
    ensure
      volume_unfreeze(vol)
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
    rescue => e
      volume_unmount
      case e.message
      when /Disk not found/
        raise Blockbridge::NotFound, "Volume not found"
      else
        raise
      end
    end

    def volume_mount
      mount_ref
      logger.info "#{vol_name} mounting if needed..."
      volume_cmd_exec("bb_attach")
      volume_cmd_exec("bb_mkfs")
      volume_cmd_exec("bb_mount")
      logger.info "#{vol_name} mounted"
    rescue => e
      volume_unmount
      case e.message
      when /Disk not found/
        raise Blockbridge::NotFound, "Volume not found"
      else
        raise
      end
    end

    def volume_unmount
      mount_unref
      return if mount_needed?
      logger.info "#{vol_name} unmounting..."
      volume_cmd_exec("bb_unmount")
      while true
        begin
          volume_cmd_exec("bb_detach", BLOCKBRIDGE_DETACH_FAIL: "1")
          break
        rescue => e
          case e.message
          when /Could not logout of all requested sessions/
            logger.debug "#{vol_name} detach retrying: could not log out of session"
            EM::Synchrony.sleep 1
          else
            logger.debug "#{vol_name} detach failed: #{e.message}"
            break
          end
        end
      end
      volume_cmd_exec("bb_detach")
      logger.info "#{vol_name} unmounted"
    rescue => e
      case e.message
      when /Disk not found/
        raise Blockbridge::NotFound, "Volume not found"
      else
        raise
      end
    end
  end
end
