# Copyright (c) 2015-2016, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

e = data

case e
when RuntimeSuccess
  msg = e.message.word_wrap(76)
  puts msg.each_line { |line| puts "  #{line}" }

when Clamp::UsageError
  msg = e.message.word_wrap(70)
  msg.lines.each_with_index do |line, idx|
    if idx == 0
      puts "ERROR: #{line}"
    else
      puts "       #{line}"
    end
  end
  puts ""
  puts "See: '#{e.command.invocation_path} --help'"

when RuntimeError
  msg = e.message.word_wrap(70)
  msg.lines.each_with_index do |line, idx|
    if idx == 0
      puts "ERROR: #{line}"
    else
      puts "       #{line}"
    end
  end

when Excon::Error::NotFound
  response = MultiJson.load(e.response.body, symbolize_keys: true) rescue nil
  if response
    puts "ERROR: #{response[:Error]}"
  else
    puts "ERROR: Volume not found"
  end

when Excon::Error::BadRequest
  response = MultiJson.load(e.response.body, symbolize_keys: true) rescue nil
  if response
    puts "ERROR: #{response[:Error]}"
  else
    puts "ERROR: #{e.command_instance.invocation_path} failed with a bad request"
  end

  puts ""
  puts "See: '#{e.command_instance.invocation_path} --help'"

when Excon::Error::Conflict
  response = MultiJson.load(e.response.body,symbolize_keys: true) rescue nil
  if response
    puts "ERROR: #{response[:Error]}"
  else
    puts "ERROR: Volume conflict."
  end

when Clamp::HelpWanted
  # display help with our custom builder.
  puts e.command.class.help(e.command.invocation_path,
                            HelpBuilder.new(opts))

else
  if ENV['BLOCKBRIDGE_DIAGS']
    puts "UNHANDLED EXCEPTION: #{e.message.chomp} (#{e.class})"
  else
    puts "ERROR: #{e.message.chomp}"
  end
end
