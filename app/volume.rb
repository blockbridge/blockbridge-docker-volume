# Copyright (c) 2015, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

module Blockbridge
  module Volume
    def volume_env
      env = { 
        "BB_MANUAL_MODE"             => "1",
        "LABEL"                      => vol_name,
        "BLOCKBRIDGE_VOLUME_NAME"    => vol_name,
        "BLOCKBRIDGE_VOLUME_TYPE"    => vol_type,
        "BLOCKBRIDGE_VOLUME_PATH"    => vol_path,
        "BLOCKBRIDGE_MOUNT_PATH"     => mnt_path,
        "BLOCKBRIDGE_MODULES_EXPORT" => "1",
        "BLOCKBRIDGE_API_KEY"        => api_token,
        "BLOCKBRIDGE_API_HOST"       => api_host,
        "BLOCKBRIDGE_API_SU"         => vol_user,
      }

      File.foreach(env_file).map do |line|
        line.chomp!
        next if line.match('^#')
        k, v = line.split('=')
        if k != "USER" && k != "TYPE"
          env["#{k}"] = "#{v}"
        end
      end
      env
    end

    def volume_create
      logger.info "#{vol_name} creating..."
      volume_provision
      volume_mkfs
      volume_ref
      logger.info "#{vol_name} created"
    rescue
      cmd_exec("bb_remove") rescue nil
      raise
    end

    def volume_remove
      if !volume_needed?
        logger.info "#{vol_name} removing..."
        cmd_exec("bb_remove")
        logger.info "#{vol_name} removed"
      end
      volume_unref
    end

    def volume_provision
      logger.info "#{vol_name} provisioning if needed..."
      cmd_exec("bb_provision")
      logger.info "#{vol_name} provisioned"
    end

    def volume_mkfs
      begin
        cmd_exec("bb_mkfs")
      rescue
        logger.info "#{vol_name} formatting..."
        cmd_exec("bb_attach")
        cmd_exec("bb_mkfs")
        cmd_exec("bb_detach")
        logger.info "#{vol_name} formatted"
      end
    end

    def volume_mount
      mount_ref
      logger.info "#{vol_name} mounting if needed..."
      cmd_exec("bb_attach")
      cmd_exec("bb_mount")
      logger.info "#{vol_name} mounted"
    end

    def volume_unmount
      mount_unref
      return if mount_needed?
      logger.info "#{vol_name} unmounting..."
      cmd_exec("bb_unmount")
      cmd_exec("bb_detach")
      logger.info "#{vol_name} unmounted"
    end
  end
end

