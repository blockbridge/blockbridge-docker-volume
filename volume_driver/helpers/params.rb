# Copyright (c) 2015-2016, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

module Helpers
  module Params
    def self.volume_sessions
      @@sessions ||= {}
    end

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

      pp params
    end

    def parse_params_name
      return unless params[:Name] && params[:Name].include?('=')
      return params[:Opts][:name] if params[:Opts]
    end

    def params_name
      return params[:Name]
    end

    def session_token_valid?(otp)
      return unless Params.volume_sessions[vol_name]
      return unless Params.volume_sessions[vol_name][:otp] == otp
      true
    end

    def get_session_token(otp)
      return unless session_token_valid?(otp)
      Params.volume_sessions[vol_name][:token]
    end

    def set_session_token(otp, token)
      Params.volume_sessions[vol_name] = {
        otp: otp,
        token: token,
      }
    end
  end
end
