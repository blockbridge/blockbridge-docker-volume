# Copyright (c) 2015-2016, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

module Helpers
  module Backup
    def backup_ls
      backups = []
      s3s = bbapi.obj_store.list
      s3s.each do |s3|
        backups.concat bb_lookup_backups(s3)
      end
      backups
    end

    def backup_info_keys
      [
        "id",
        "uuid",
        "serial",
        "label",
        "notes",
        "status",
        "location",
        "bucket_name",
        "host_name",
        "protocol",
        "uri_style",
        "access_key_id",
        "secret_access_key_set",
        "security_token_set",
      ]
    end

    def backup_info
      s3s = bbapi.obj_store.list
      s3s.map do |s3|
        s3.keep_if { |k, v| backup_info_keys.include? k }
      end
    end

    def backup_inspect
      s3, backup = bb_lookup_s3(volume_params[:s3], volume_params[:backup])
      backup
    end

    def backup_rm
      s3, backup = bb_lookup_s3(volume_params[:s3], volume_params[:backup])
      bbapi.obj_store.remove_backup(s3.id, backup[:id])
    end
  end
end
