# Copyright (c) 2015-2017, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

module Helpers
  module Cache
    def self.volumes
      @@volumes ||= {}
    end

    def vol_cache_ref
      'docker-volumes-cache'
    end

    def vol_cache_path(name = nil)
      File.join(vol_path(name), 'cache')
    end

    def vol_cache_add(name = vol_name, opts = volume_params, replace = false)
      return if vol_cache_enabled?(name)
      return unless name && opts
      return if File.exist?(vol_cache_path(name)) unless replace
      FileUtils.mkdir_p(File.dirname(vol_cache_path(name)))
      tmp_file = Dir::Tmpname.make_tmpname(vol_cache_path(name), nil)
      File.open(tmp_file, 'w+') do |f|
        f.write(opts.to_json)
        f.fsync rescue nil
      end
      File.rename(tmp_file, vol_cache_path(name))
      Blockbridge::VolumeCacheMonitor.cache.reset
    rescue => e
      logger.info "vol_cache_add failed: #{e.message}"
    end

    def vol_cache_get(name = vol_name)
      File.open(vol_cache_path(name), 'r') do |f|
        dat = f.read
        JSON.parse(dat, { :symbolize_names => true })
      end
    rescue
    end

    def vol_cache_rm(name = vol_name)
      FileUtils.rm_rf(File.dirname(vol_cache_path(name)))
      Cache.volumes.delete(name)
    end

    def vol_cache_enable(name = vol_name)
      Cache.volumes[name] = true
    end

    def vol_cache_disable(name = vol_name)
      Cache.volumes.delete(name)
    end

    def vol_cache_enabled?(name = vol_name)
      Cache.volumes[name] == true
    end

    def vol_cache_foreach(&blk)
      Dir.foreach(volumes_root) do |v|
        next if v == '.' || v == '..'
        next unless (vol = vol_cache_get(v))
        blk.call v, vol
      end
    end
  end
end
