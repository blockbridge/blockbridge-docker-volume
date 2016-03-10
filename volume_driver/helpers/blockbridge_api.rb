# Copyright (c) 2015-2016, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

require 'blockbridge/api'

module Helpers
  module BlockbridgeApi
    def self.bbapi_client
      @@bbapi_client ||= {}
    end

    def bbapi_client_handle(user)
      "#{access_token}:#{user}"
    end

    def access_token
      @access_token ||= api_token
    end

    def url
      "https://#{api_host}/api"
    end

    def client_params(user)
      Hash.new.tap do |p|
        p[:user] = user || ''
        if user
          p[:default_headers] = {
            'X-Blockbridge-SU' => user,
          }
        end
        p[:url] = url
      end
    end

    def bbapi(user = nil)
      BlockbridgeApi.bbapi_client[bbapi_client_handle(user)] ||=
        begin
          Blockbridge::Api::Client.defaults[:ssl_verify_peer] = false
          Blockbridge::Api::Client.new_oauth(access_token, client_params(user))
        end
    end
  end
end
