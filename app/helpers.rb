# Copyright (c) 2015, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

module Blockbridge
  module Helpers
    def logger
      env.logger
    end

    def env_file
      File.join(ENV['BLOCKBRIDGE_ENV_ROOT'], params[:Name])
    end

    def mnt_path
      File.join(ENV['BLOCKBRIDGE_MNT_ROOT'], params[:Name])
    end

    def vol_name
      "volume-#{params[:Name]}"
    end

    def api_token
      ENV['BLOCKBRIDGE_API_KEY']
    end

    def api_host
      ENV['BLOCKBRIDGE_API_HOST']
    end

    def check_name
      return unless params[:Name]
      return if File.exist?(env_file)
      raise "Volume '#{params[:Name]}' is not configured; no parameters defined in #{env_file}"
    end

    def docker_run(name, opts, force: false, noop: false)
      begin
        # create container
        logger.debug "docker: creating #{name} from #{opts['Image']}"
        cont = Docker::Container.create(opts.clone)
      rescue Docker::Error::NotFoundError
        # image not found; pull it first 
        logger.debug "#{opts['Image']} not found"
        logger.debug "docker: pulling image #{opts['Image']}"
        Docker::Image.create('fromImage' => opts['Image'])
        logger.debug "docker: creating #{name} from #{opts['Image']}"
        cont = Docker::Container.create(opts.clone)
      rescue Docker::Error::ConflictError
        logger.debug "docker: #{name} already exists"
        return if noop
        raise if !force

        # remove and re-run on conflict
        docker_remove(name, volumes: true, force: true)
        cont = docker_run(name, opts)
      end

      # run container
      cont.start

      # return container
      cont
    end

    def docker_remove(name, volumes: false, force: false)
      # remove volume as gently as possible
      cont = Docker::Container.get(name)
      logger.debug "docker: removing #{name}"
      cont.stop('timeout' => 10) rescue nil
      cont.kill('signal' => 'SIGINT') rescue nil
      cont.remove('v' => volumes, 'force' => force)
    rescue Docker::Error::NotFoundError
      # noop on not found
    end

    def docker_exec(cmd)
      # get volume
      cont = Docker::Container.get(vol_name)

      # exec
      out, err, sts = cont.exec(cmd.split)
      if sts != 0
        raise "#{vol_name} exec failed: #{cmd}: #{(out + err).join("\n")}"
      end
    end

    def check_iscsid
      return unless params[:Name]

      iscsi_opts = {
        'name' => 'iscsid',
        'Image' => 'blockbridge/iscsid',
        'HostConfig' => {
          Privileged: true,
          Binds: [
            "/proc/1/ns:/ns-net",
            "/lib/modules:/lib/modules",
          ],
          RestartPolicy: { 'Name' => 'always' },
        },
      }

      begin
        # check state and re-run if not running
        cont = Docker::Container.get(iscsi_opts['name'])
        return if cont.info['State']['Running'] && cont.info['State']['Restarting'] == false
        cont = docker_run(iscsi_opts['name'], iscsi_opts, force: true)
      rescue
        cont = docker_run(iscsi_opts['name'], iscsi_opts, noop: true)
      end

      # check state again
      cont = Docker::Container.get(iscsi_opts['name'])
      return if cont.info['State']['Running'] && cont.info['State']['Restarting'] == false
      raise "iscsid container is not operating correctly"
    end

    def volume_params
      user = nil
      image = nil

      # set initial environment
      env = [ "BB_MANUAL_MODE=1" ]
      env << "LABEL=#{vol_name}"
      env << "BLOCKBRIDGE_VOLUME_NAME=#{vol_name}"
      env << "BLOCKBRIDGE_MOUNT_PATH=#{mnt_path}"
      env << "BLOCKBRIDGE_MODULES_EXPORT=1"
      env << "BLOCKBRIDGE_API_KEY=#{api_token}"
      env << "BLOCKBRIDGE_API_HOST=#{api_host}"

      # read in environment file for volume
      File.foreach(env_file).map do |line|
        line.chomp!

        next if line.match('^#')

        k, v = line.split('=')
        if k == "TYPE"
          image = "blockbridge/#{v}"
        elsif k == "USER"
          user = v
          env << "BLOCKBRIDGE_API_SU=#{user}"
        else
          env << line
        end
      end

      raise "USER not found in #{env_file}" if user.nil?
      raise "TYPE not found in #{env_file}" if image.nil?

      return image, env
    end

    def volume_create
      logger.info "#{vol_name} creating..."

      # setup params
      volimage, volenv = volume_params

      # create options
      volopts = {
        'name'  => vol_name,
        'Image' => volimage,
        'HostConfig' => {
          Privileged: true,
          Binds: [
            "/proc/1/ns:/ns-net",
            "/proc/1/ns:/ns-mnt",
          ],
          VolumesFrom: [
            "iscsid",
          ],
        },
        'Env' => volenv
      }

      # create volume
      docker_run(vol_name, volopts)
      logger.info "#{vol_name} created"
    end

    def volume_create_fail
      docker_exec("/bb/bb_remove") rescue nil
      docker_remove(vol_name, volumes: true, force: true) rescue nil
    end

    def volume_remove
      logger.info "#{vol_name} removing..."
      docker_exec("/bb/bb_remove")
      docker_remove(vol_name, volumes: true, force: true)
      logger.info "#{vol_name} removed"
    end

    def volume_provision
      logger.info "#{vol_name} provisioning..."
      docker_exec("/bb/bb_provision")
      logger.info "#{vol_name} provisioned"
    end

    def volume_attach
      logger.info "#{vol_name} attaching..."
      docker_exec("/bb/bb_attach")
      logger.info "#{vol_name} attached"
    end

    def volume_detach
      logger.info "#{vol_name} detaching..."
      docker_exec("/bb/bb_detach")
      logger.info "#{vol_name} detached"
    end

    def volume_mkfs
      begin
        docker_exec("/bb/bb_mkfs")
      rescue
        logger.info "#{vol_name} formatting..."
        docker_exec("/bb/bb_attach")
        docker_exec("/bb/bb_mkfs")
        docker_exec("/bb/bb_detach")
        logger.info "#{vol_name} formatted"
      end
    end

    def volume_mount
      logger.info "#{vol_name} mounting..."
      docker_exec("/bb/bb_mount")
      logger.info "#{vol_name} mounted"
    end

    def volume_unmount
      logger.info "#{vol_name} unmounting..."
      docker_exec("/bb/bb_unmount")
      logger.info "#{vol_name} unmounted"
    end
  end
end
