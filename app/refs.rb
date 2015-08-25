# Copyright (c) 2015, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

module Blockbridge
  module Refs
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
      Dir.foreach(volumes_root) do |vol|
        if vol != '.' && vol != '..'
          FileUtils.rm_rf(File.join(volumes_root, vol, 'ref'))
        end
      end
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
  end
end
