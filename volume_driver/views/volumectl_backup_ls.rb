# Copyright (c) 2015-2016, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

if data.length == 0
  header "No backups found."
  return
end

table(sort_cols: %w(User S3 Label ID), max_width: 250) do |t|
  t.cols('Label', 'ID', 'User', 'S3', 'Date', 'Description')

  data.each do |b|
    t << [ b['label'], b['id'], b['user'], b['s3'], b['completed_at'], b['description'] ]
  end
end
