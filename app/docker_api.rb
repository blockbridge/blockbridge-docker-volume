# Copyright (c) 2015, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

module Blockbridge
  module Docker
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
  end
end

