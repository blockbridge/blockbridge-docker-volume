# Copyright (c) 2015, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

e = data

case e
when Blockbridge::CLI::RuntimeSuccess
when Clamp::HelpWanted
  raw render :exception_human, data, options
when Blockbridge::Api::ExecutionError, Blockbridge::Api::ConflictError
  puts "#{e.class} #{e.errors.first[:type]} #{e.errors.first[:qualifier] || ''}"
else
  puts "#{e.class} #{e}"
end
