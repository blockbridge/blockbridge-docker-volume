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
      "https://#{api_host}/api" if api_host
      api_url if api_url
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

    def bb_lookup(user, vol_name)
      vols = bbapi(user).vdisk.list(label: vol_name)
      raise Blockbridge::NotFound if vols.empty?
      vols.first
    end

    def bb_remove(user, vol_name)
      disk = bb_lookup(user, vol_name)
      bbapi(user).objects.remove_by_xref("#{volume_ref_prefix}#{vol_name}", scope: "vdisk,xmd")
      if bbapi(user).vdisk.list(vss_id: disk.vss_id).empty?
        bbapi(user).vss.remove(disk.vss_id)
      end
    rescue Blockbridge::NotFound
    end

    def bb_is_attached(user, vol_name)
      disk = bb_lookup(user, vol_name)
      disk.xmd_refs.any? { |x| x.start_with? "host-attach" }
    rescue Blockbridge::NotFound
    end
  end
end
