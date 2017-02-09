# Copyright (c) 2015-2017, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

unless data
  header "No volume information found."
  return
end

def info(vol)
  fieldset("Volume: #{vol['name']}", heading: true) do
    field 'type', vol['type']
    field 'user', vol['user']
    field 'capacity', vol['capacity']
    if vol['backup']
      backup_str = nil
      if vol['s3']
        backup_str = "#{vol['s3']}/#{vol['backup']}"
      else
        backup_str = "backup:#{vol['backup']}"
      end
      field 'from backup', backup_str
    end
  end
end

if data.is_a? Array
  data.each do |d|
    info d
  end
else
  info data
end
