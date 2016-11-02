# Copyright (c) 2015-2016, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

if data.length == 0
  header "No Object stores found."
  return
end

table(sort_cols: %w(Object-store), max_width: 135) do |t|
  t.cols('Object-store', 'Bucket', 'Host', 'Protocol', 'Location', 'Status')

  data.each do |obj|
    obj_str = obj['label'] ? obj['label'] : obj['serial']
    loc_str = [ obj['location']['city'], obj['location']['state'], obj['location']['country'] ].reject { |d| d.empty? }.join(', ')
    sts_str = obj['status']['value'] == 'online' ? 'OK' : "#{obj['status']['value']}: #{obj['status']['detail']}"

    t << [ obj_str, obj['bucket_name'], obj['host_name'], obj['protocol'], loc_str.empty? ? '-' : loc_str, sts_str ]
  end
end
