# Copyright (c) 2015, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

require 'tempfile'
require 'fileutils'
require 'socket'

module Blockbridge
  module Helpers
    def logger
      env.logger
    end

    def env_file
      File.join(ENV['BLOCKBRIDGE_ROOT'], 'env', params[:Name])
    end

    def mnt_path
      File.join(ENV['BLOCKBRIDGE_ROOT'], 'mnt', params[:Name])
    end

    def vol_ref_path
      File.join(ENV['BLOCKBRIDGE_ROOT'], 'ref', 'volume')
    end

    def vol_ref_file
      File.join(vol_ref_path, params[:Name])
    end

    def mnt_ref_path
      File.join(ENV['BLOCKBRIDGE_ROOT'], 'ref', 'mount')
    end

    def mnt_ref_file
      File.join(mnt_ref_path, params[:Name])
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
        logger.debug "docker creating #{name} from #{opts['Image']}"
        cont = Docker::Container.create(opts.clone)
      rescue Docker::Error::NotFoundError
        logger.debug "#{opts['Image']} not found"
        logger.debug "docker pulling image #{opts['Image']}"
        Docker::Image.create('fromImage' => opts['Image'])
        logger.debug "docker creating container #{name} from #{opts['Image']}"
        cont = Docker::Container.create(opts.clone)
      rescue Docker::Error::ConflictError
        logger.debug "docker container #{name} already exists"
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
      logger.debug "docker removing #{name}"
      cont.stop('timeout' => 10) rescue nil
      cont.kill('signal' => 'SIGINT') rescue nil
      cont.remove('v' => volumes, 'force' => force)
    rescue Docker::Error::NotFoundError
      # noop on not found
    end

    def docker_exec(cmd)
      cont = Docker::Container.get(vol_name)
      out, err, sts = cont.exec(cmd.split)
      if sts != 0
        raise "#{vol_name} #{cmd} failed: #{(out + err).join("\n")}"
      end
      out.each do |m|
        msg = m.chomp.squeeze("\n")
        msg.each_line do |m| logger.info "#{vol_name} #{m.chomp}" end
      end
    end

    def check_iscsid
      return unless params[:Name]

      iscsi_opts = {
        'name' => 'iscsid',
        'Image' => 'blockbridge/iscsid',
        'Hostname' => Socket.gethostname,
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

    def get_ref(ref_file)
      begin
        File.open(ref_file, 'r') do |f|
          dat = f.read
          JSON.parse(dat)
        end
      rescue
        FileUtils.mkdir_p(File.dirname(ref_file))
        File.open(ref_file, 'w+') do |f|
          dat = { 'ref' => 0 }
          f.write(dat.to_json)
          f.fsync rescue nil
          dat
        end
      end
    end

    def set_ref(ref_file, dat)
      tmp_file = Dir::Tmpname.make_tmpname(ref_file, nil)
      File.open(tmp_file, 'w') do |f|
        f.write(dat.to_json)
        f.fsync rescue nil
      end
      File.rename(tmp_file, ref_file)
    end

    def ref_incr(file, desc)
      dat = get_ref(file)
      logger.debug "#{vol_name} #{desc} #{dat['ref']} => #{dat['ref'] + 1}"
      dat['ref'] += 1
      set_ref(file, dat)
    end

    def ref_decr(file, desc)
      dat = get_ref(file)
      return if dat['ref'] == 0
      logger.debug "#{vol_name} #{desc} #{dat['ref']} => #{dat['ref'] - 1}"
      dat['ref'] -= 1
      set_ref(file, dat)
    end

    def volume_ref
      ref_incr(vol_ref_file, "reference")
    end

    def volume_unref
      ref_decr(vol_ref_file, "reference")
    end

    def mount_ref
      ref_incr(mnt_ref_file, "mounts")
    end

    def mount_unref
      ref_decr(mnt_ref_file, "mounts")
    end

    def unref_all
      FileUtils.rm_rf(mnt_ref_path)
    end

    def volume_needed?
      dat = get_ref(vol_ref_file)
      return true if dat && dat['ref'] > 1
      false
    end

    def mount_needed?
      dat = get_ref(mnt_ref_file)
      return true if dat && dat['ref'] > 0
      false
    end

    def volume_exists?
      logger.info "#{vol_name} lookup..."
      cont = Docker::Container.get(vol_name)
      cont.info['State']['Running']
    rescue Docker::Error::NotFoundError
      false
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

    def volume_run
      return if volume_exists?

      # setup params
      volimage, volenv = volume_params

      # create options
      volopts = {
        'name'  => vol_name,
        'Image' => volimage,
        'Hostname' => Socket.gethostname,
        'HostConfig' => {
          Privileged: true,
          Binds: [
            "/proc/1/ns:/ns-net",
            "/proc/1/ns:/ns-mnt",
          ],
          RestartPolicy: { 'Name' => 'always' },
          VolumesFrom: [
            "iscsid",
          ],
        },
        'Env' => volenv
      }

      # create volume
      docker_run(vol_name, volopts, force: true)
    end

    def volume_create
      logger.info "#{vol_name} creating..."
      volume_run
      begin
        volume_provision
        volume_mkfs
        logger.info "#{vol_name} created"
      rescue
        docker_exec("bb_remove") rescue nil
        docker_remove(vol_name, volumes: true, force: true) rescue nil
        raise
      end
    end

    def volume_remove
      return if volume_needed?
      logger.info "#{vol_name} removing..."
      docker_exec("bb_remove")
      docker_remove(vol_name, volumes: true, force: true)
      logger.info "#{vol_name} removed"
    end

    def volume_provision
      logger.info "#{vol_name} provisioning if needed..."
      docker_exec("bb_provision")
      logger.info "#{vol_name} provisioned"
    end

    def volume_mkfs
      begin
        docker_exec("bb_mkfs")
      rescue
        logger.info "#{vol_name} formatting..."
        docker_exec("bb_attach")
        docker_exec("bb_mkfs")
        docker_exec("bb_detach")
        logger.info "#{vol_name} formatted"
      end
    end

    def volume_mount
      logger.info "#{vol_name} mounting if needed..."
      docker_exec("bb_attach")
      docker_exec("bb_mount")
      logger.info "#{vol_name} mounted"
    end

    def volume_unmount
      return if mount_needed?
      logger.info "#{vol_name} unmounting..."
      docker_exec("bb_unmount")
      docker_exec("bb_detach")
      logger.info "#{vol_name} unmounted"
    end

    def self.locks
      @@locks ||= {}
    end

    def synchronize(&blk)
      lock = Helpers.locks[vol_name] ||= {
        mutex: EM::Synchrony::Thread::Mutex.new,
        ref:   0
      }
      lock[:ref] += 1
      lock[:mutex].synchronize(&blk)
      lock[:ref] -= 1
      Helpers.locks.delete(vol_name) if lock[:ref] == 0
    end
  end
end
