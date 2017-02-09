# Copyright (c) 2015-2016, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

if data.length == 0
  header "No profiles found."
  return
end

table(sort_cols: %w(User Name)) do |t|
  t.cols('Name', 'User', 'Type', 'Capacity', 'Transport', 'Attributes')

  data.each do |profile|
    transport_str = profile['transport'].to_s.empty? ? 'insecure' : profile['transport']
    t << [ profile['name'], profile['user'], profile['type'], profile['capacity'], transport_str, profile['attributes'] ]
  end
end
