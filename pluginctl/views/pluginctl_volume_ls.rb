# Copyright (c) 2015-2017, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

if data.length == 0
  header "No volumes found."
  return
end

table(sort_cols: %w(User Name)) do |t|
  t.cols('Name', 'User', 'Capacity', 'Source')

  data.each do |vol|
    src_str = nil
    if vol['backup']
      if vol['s3']
        src_str = "backup:#{vol['s3']}/#{vol['backup']}"
      else
        src_str = "backup:#{vol['backup']}"
      end
    end

    t << [ vol['name'], vol['user'], vol['capacity'], src_str ]
  end
end
