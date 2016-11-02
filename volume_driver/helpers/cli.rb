# Copyright (c) 2015-2016, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

require 'hashie'

module Helpers
  module Cli
    def machine?
      !!(ENV['BLOCKBRIDGE_MACHINE_FORMAT'].to_i != 0 || ARGV.index('--machine'))
    end

    def debug?
      !!(ENV['BLOCKBRIDGE_DEBUG'].to_i != 0 || ARGV.index('--debug'))
    end

    def verbose?
      !!(ENV['BLOCKBRIDGE_VERBOSE'].to_i != 0 || ARGV.index('--verbose'))
    end

    def debug_log(*args)
      return unless debug?
      args.each do |a|
        a.each_line { |l| STDERR.puts "[D] #{l}" }
      end
    end

    extend self

    BYTE_UNITS = {
      'KiB' => 1024,
      'MiB' => 1024 ** 2,
      'GiB' => 1024 ** 3,
      'TiB' => 1024 ** 4,
      'PiB' => 1024 ** 5,
      'K'   => 1024,
      'k'   => 1000,
      'M'   => 1000 ** 2,
      'G'   => 1000 ** 3,
      'T'   => 1000 ** 4,
      'P'   => 1000 ** 5,
      'kB'  => 1000,
      'MB'  => 1000 ** 2,
      'GB'  => 1000 ** 3,
      'TB'  => 1000 ** 4,
      'PB'  => 1000 ** 5,
      ''    => 1,
    }

    def parse_bytes(str)
      return str if str.is_a?(Integer)
      if md = /^([\d.]+)\s*([A-Za-z]*)$/.match(str)
        if BYTE_UNITS.has_key? md[2]
          md[1].to_i * BYTE_UNITS[md[2]]
        else
          raise ArgumentError, "Invalid unit string: '#{md[2]}'"
        end
      else
        raise ArgumentError, "Invalid byte value: '#{str}'"
      end
    end

    TRUTHY_BOOLS = %w(1 true yes on enable enabled)
    FALSY_BOOLS = %w(0 false no off disable disabled)
    def parse_boolean(str)
    if TRUTHY_BOOLS.include? str
      true
    elsif FALSY_BOOLS.include? str
      false
    else
      signal_usage_error "Invalid boolean value: #{str}"
    end
    end

    def format_json(o)
      case o
      when nil
        'null'
      when String
        "\"#{o}\""
      when Integer, Float, TrueClass, FalseClass
        o.to_s
      else
        JSON.generate(o)
      end
    end

    def format_time(t)
      if t.is_a? String
        Time.parse(t).to_s
      else
        Time.at(t / 1000)
      end
    end

    def format_label(val)
      Paint[val, :bold]
    end

    def format_serial(ser)
      ser
    end

    def format_status(sts)
      return color("unknown", :red) if !sts

      sts_val    = sts.value
      sts_detail = sts.detail
      sts_ind    = sts.indicator
      sts_str    = sts_val
      sts_str   += " (#{sts_detail})" if sts_detail.length > 0

      case sts_ind
      when 'online'
        Paint[sts_str, :green]
      when 'degraded'
        Paint[sts_str, :yellow]
      when 'offline'
        Paint[sts_str, :red]
      end

      sts_str
    end

    def format_duration(time_ms)
      secs  = time_ms.to_int / 1000
      mins  = secs / 60
      hours = mins / 60
      days  = hours / 24

      if days > 0
        day_str = days == 1 ? "1 day" : "#{days} days"
        hour_remainder = hours % 24
        if hour_remainder > 0
          hour_str = hour_remainder == 1 ? 'hour' : 'hours'
          "#{day_str} and #{hour_remainder} #{hour_str}"
        else
          day_str
        end
      elsif hours > 0
        hour_str = hours == 1 ? "1 hour" : "#{hours} hours"
        min_remainder = mins % 60
        if min_remainder > 0
          min_str = min_remainder == 1 ? 'minute' : 'minutes'
          "#{hour_str} and #{min_remainder} #{min_str}"
        else
          hour_str
        end
      elsif mins > 0
        min_str = mins == 1 ? "1 minute" : "#{mins} minutes"
        sec_remainder = secs % 60
        if sec_remainder > 0
          sec_str = sec_remainder == 1 ? 'second' : 'seconds'
          "#{min_str} and #{sec_remainder} #{sec_str}"
        else
          min_str
        end
      elsif secs == 1
        "#{secs} second"
      elsif secs >= 0
        "#{secs} seconds"
      end
    end

    @@kib = 1024
    @@mib = 1024 * @@kib
    @@gib = 1024 * @@mib
    @@tib = 1024 * @@gib
    @@pib = 1024 * @@tib
    def scale_bytes_base2(amount)
      amount = amount.to_f
      return [ 0, "b" ] if amount == 0
      return [ amount.to_i, "b" ] if amount < @@kib
      return [ (amount / @@kib).round(1), "KiB" ] if amount < @@mib
      return [ (amount / @@mib).round(2), "MiB" ] if amount < @@gib
      return [ (amount / @@gib).round(3), "GiB" ] if amount < @@tib
      return [ (amount / @@tib).round(4), "TiB" ] if amount < @@pib
      return [ (amount / @@pib).round(5), "PiB" ]
    end

    @@kb = 1000
    @@mb = 1000 * @@kb
    @@gb = 1000 * @@mb
    @@tb = 1000 * @@gb
    @@pb = 1000 * @@tb
    def scale_bytes_base10(amount)
      amount = amount.to_f
      return [ 0, "b" ] if amount == 0
      return [ amount.to_i, "b" ] if amount < @@kb
      return [ (amount / @@kb).round(1), "KB" ] if amount < @@mb
      return [ (amount / @@mb).round(2), "MB" ] if amount < @@gb
      return [ (amount / @@gb).round(3), "GB" ] if amount < @@tb
      return [ (amount / @@tb).round(4), "TB" ] if amount < @@pb
      return [ (amount / @@pb).round(5), "PB" ]
    end

    def format_bytes(amount)
      b2 = scale_bytes_base2(amount)
      if b2[0].truncate != b2[0] || b2[1] == 'b'
        b10 = scale_bytes_base10(amount)
        if b10[0].truncate == b10[0]
          return b10.join('')
        end
      end
      b2.join('')
    end

    def format_bytes_base2(amount)
      b2 = scale_bytes.base2(amount)
      b2.join('')
    end

    def format_bytes_base10(amount)
      b10 = scale_bytes_base10(amount)
      b10.join('')
    end

    def format_bytes_ratio(fraction, fmt: "%.2f", **opts)
      num = fraction[0]
      denom = fraction[1]

      return if num.nil? || denom.nil?

      actual = format_bytes(num)

      if denom > 0 && num > 0
        pct = "%.2f" % (Float(num) / denom * 100)
        "#{actual} (#{pct}%)"
      else
        actual
      end
    end

    def format_ratio(fraction, fmt: "%.2f", **opts)
      num = fraction[0]
      denom = fraction[1]

      return if num.nil? || denom.nil?

      if denom > 0 && num > 0
        pct = fmt % (Float(num) / denom * 100)
        "#{num} (#{pct}%)"
      else
        num
      end
    end

    def format_bandwidth(val, **opts)
      "#{format_bytes(val)}/s"
    end

    def format_percent(val, **opts)
      "#{val}%"
    end

    def format_time_of_day(val, **opts)
      Tod::TimeOfDay.from_second_of_day(val.to_i/1000).to_s
    end

    def format_value(val, cast: nil, **opts)
      return if val.nil? && !opts[:nil_str]

      if block_given?
        val = yield val
      end

      if val.nil?
        if opts[:nil_str].respond_to?(:to_str)
          # allow a custom placeholder to be specified
          val = opts[:nil_str]
        else
          val = "null"
        end
      else
        # don't try to format nil values
        val = case cast
              when :bytes
                format_bytes(val)
              when :bytes_base2
                format_bytes_base2(val)
              when :bytes_base10
                format_bytes_base10(val)
              when :bandwidth
                format_bandwidth(val, **opts)
              when :bytes_ratio
                format_bytes_ratio(val, **opts)
              when :ratio
                format_ratio(val, **opts)
              when :percent
                format_percent(val, **opts)
              when :time
                format_time(val)
              when :time_of_day
                format_time_of_day(val)
              when :duration
                format_duration(val)
              when :duration_s
                format_duration(val * 1000)
              when :bool_yn
                val ? 'yes' : 'no'
              when :bool_set
                val ? '-set-' : '-unset-'
              when :bool_enabled
                val ? 'enabled' : 'disabled'
              when :cjoin
                val.empty? ?
                  opts[:empty_str] || color('none', :red) :
                  val.join(', ')
              else
                val
              end
      end

      # if the formatter returned nil, convert it to nil_str, if one is set.
      val.nil? ? opts[:nil_str] : val.to_s
    end
  end
end
