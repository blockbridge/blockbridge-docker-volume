# Copyright (c) 2015-2017, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

module Helpers
  module Params
    def parse_params(params)
      return unless params[:Name] && params[:Name].include?('=')
      params[:Opts] ||= {}

      # find leading 'name(,key=val...)'
      params[:Name].scan(/(\A[^,]+)/) do |val|
        next if val[0].include?('=')
        params[:Opts][:name] = val[0]
      end

      # find 'key=val(,key=val...)
      params[:Name].sub(/\A#{params[:Opts][:name]},/, '').scan(/([^=,]+)=([^=,]+)/) do |key, val|
        params[:Opts][key.to_sym] = val
      end
    end

    def parse_params_name
      return unless params[:Name] && params[:Name].include?('=')
      return params[:Opts][:name] if params[:Opts]
    end

    def params_name
      return params[:Name]
    end

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
      if md = /^([\d.]+)\s*([A-Za-z]*)$/.match(str)
        if BYTE_UNITS.has_key? md[2]
          (md[1].to_f * BYTE_UNITS[md[2]]).to_i
        else
          signal_usage_error "Invalid unit string: '#{md[2]}'"
        end
      else
        signal_usage_error "Invalid byte value: '#{str}'"
      end
    end

    def parse_tag_query(tq)
      tq = tq.split(/\s+/) if tq.respond_to? :to_str

      Hash.new.tap do |p|
        h = p[:tags] = { include: [], exclude: [] }

        tq.each do |ts|
          tt = ts[0]
          tv = ts[1..-1]

          next if tv.nil? || tv.empty?

          case tt
          when '+'
            h[:include].push(tv)
          when '-'
            h[:exclude].push(tv)
          end
        end
      end
    end
  end
end
