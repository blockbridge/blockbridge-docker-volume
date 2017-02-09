# Copyright (c) 2015-2017, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

module Blockbridge
  class HelpBuilder
    def initialize(opts = {})
      @out = StringIO.new
      @opts = opts
    end

    def string
      @out.string
    end

    def add_usage(invocation_path, usage_descriptions)
      puts "Usage:"
      usage_descriptions.each do |usage|
        puts "    #{invocation_path} #{usage}".rstrip
      end
    end

    def add_description(description)
      if description
        puts ""
        puts description.gsub(/^/, "    ")
      end
    end

    DETAIL_FORMAT = "    %-29s %s"

    def add_list(heading, items)
      # optionally group items
      item_groups = items.group_by { |i| i.options[:group] }

      item_groups.each_pair do |name, items|
        visible, hidden = items.partition do |i|
          @opts[:verbose] || !i.hidden?
        end

        # skip empty option group sections
        next if visible.empty?

        print "\n"

        if name
          print "#{name} #{heading.downcase}"
        else
          print heading
        end

        print " (#{hidden.length} hidden)" if hidden.length > 0
        puts  ":"

        visible.each do |item|
          label, description = item.help

          description.each_line.each_with_index do |line, i|
            puts DETAIL_FORMAT % [ i == 0 ? label : '', line ]
          end
        end
      end
    end

    private

    def print(*args)
      @out.print(*args)
    end

    def puts(*args)
      @out.puts(*args)
    end
  end
end
