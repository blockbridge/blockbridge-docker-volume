# Copyright (c) 2015-2016, Blockbridge Networks LLC.  All rights reserved.  Use
# of this source code is governed by a BSD-style license, found in the LICENSE
# file.

module Blockbridge
  class VolumeMonitor
    include Helpers
    attr_reader :config
    attr_reader :logger
    attr_reader :status
    attr_reader :cache_version

    def self.cache
      @@cache
    end

    def initialize(address, port, config, status, logger)
      @config = config
      @logger = logger
      @status = status
      @@cache = self
    end

    def monitor_interval_s
      ENV['BLOCKBRIDGE_MONITOR_INTERVAL_S'] || 30
    end

    def run
      EM::Synchrony.run_and_add_periodic_timer(monitor_interval_s, &method(:volume_monitor))
    end

    def reset
      @cache_version = nil
    end

    def volume_invalidate(name)
      logger.info "#{name} removing stale volume from docker"
      vol_cache_enable(name)
      defer do
        docker_volume_rm(name)
      end
      vol_cache_rm(name)
      logger.info "#{name} cache invalidated."
    rescue => e
      vol_cache_disable(name)
      logger.error "Failed to remove docker cached volume: #{name}: #{e.message}"
    end

    def volume_user_lookup(user)
      raise Blockbridge::Notfound if bbapi.user_profile.list(login: user).length == 0
    end

    def volume_lookup(vol)
      volume_user_lookup(vol[:user])
      bbapi(vol[:user]).xmd.info("docker-volume-#{vol[:name]}")
    rescue Excon::Errors::NotFound, Excon::Errors::Gone, Blockbridge::NotFound
    end

    def cache_status_create
      xmd = bbapi.xmd.info(vol_cache_ref) rescue nil
      return xmd unless xmd.nil?
      bbapi.xmd.create(ref: vol_cache_ref)
    rescue Blockbridge::Api::ConflictError
    end

    def cache_version_lookup
      xmd = cache_status_create
      xmd[:seq]
    rescue Excon::Errors::NotFound, Excon::Errors::Gone
    end

    def volume_async_remove(vol, vol_info, vol_env)
      if vol_info
        return unless vol_info[:data] && vol_info[:data][:deleted]
        return unless ((Time.now.tv_sec - vol_info[:data][:deleted]) > monitor_interval_s)
        res = cmd_exec_raw("bb_remove", vol_env)
        cmd_res_dump(res, vol[:name])
      end
      vol_cache_rm(vol[:name])
      logger.info "#{vol[:name]} async removed"
    rescue Blockbridge::CommandError => e
      logger.debug "#{vol[:name]} async remove: #{e.message}"
      if e.message.include? "not found"
        vol_cache_rm(vol[:name])
      end
      raise
    end

    def volume_cache_check
      new_cache_version = cache_version_lookup
      return unless new_cache_version != cache_version
      logger.info "Validating volume cache"
      revalidate = false
      vol_cache_foreach do |v, vol|
        volume_invalidate(vol[:name]) unless (vol_info = volume_lookup(vol))
        revalidate = true if vol[:deleted]
        volume_async_remove(vol, vol_info, vol[:env]) if vol[:deleted]
      end
      @cache_version = new_cache_version unless revalidate
    end

    def volume_monitor
      volume_cache_check
    rescue => e
      msg = e.message.chomp.squeeze("\n")
      msg.each_line do |m| logger.error(m.chomp) end
      #e.backtrace.each do |b| logger.error(b) end
    end
  end
end
