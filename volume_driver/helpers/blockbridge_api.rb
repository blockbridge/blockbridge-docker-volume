# Copyright (c) 2015-2016, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

require 'blockbridge/api'

module Helpers
  module BlockbridgeApi
    def self.client
      @@client ||= {}
    end

    def self.session
      @@session ||= {}
    end

    def session_token_valid?(otp)
      return unless BlockbridgeApi.session[vol_name]
      return unless BlockbridgeApi.session[vol_name][:otp] == otp
      true
    end

    def get_session_token(otp)
      return unless session_token_valid?(otp)
      BlockbridgeApi.session[vol_name][:token]
    end

    def set_session_token(otp, token)
      BlockbridgeApi.session[vol_name] = {
        otp:   otp,
        token: token,
      }
    end

    def bbapi_client_handle(user, user_token, otp)
      "#{access_token(user_token)}:#{user}:#{otp}"
    end

    def access_token(user_token)
      if user_token
        user_token
      else
        system_access_token
      end
    end

    def session_token_expires_in
      60
    end

    def client_params(user, user_token, otp)
      Hash.new.tap do |p|
        p[:user] = user || ''
        if user && user_token.nil?
          p[:default_headers] = {
            'X-Blockbridge-SU' => user,
          }
        end
        if otp
          p[:default_headers] ||= {}
          p[:default_headers]['X-Blockbridge-OTP'] = otp
        end
        p[:url] = api_url(access_token(user_token))
      end
    end

    def bbapi(user = nil, user_token = nil, otp = nil)
      BlockbridgeApi.client[bbapi_client_handle(user, user_token, otp)] ||=
        begin
          Blockbridge::Api::Client.defaults[:ssl_verify_peer] = false
          api = Blockbridge::Api::Client.new_oauth(access_token(user_token),
                                                   client_params(user, user_token, otp))
          if otp
            authz = api.oauth2_token.create(expires_in: session_token_expires_in)
            set_session_token(otp, authz.access_token)
          end
          api
        end
    end

    def bb_lookup_vol(vol_name, user, user_token = nil)
      vols = bbapi(user, user_token).vdisk.list(label: vol_name)
      raise Blockbridge::NotFound if vols.empty?
      vols.first
    end

    def bb_remove_vol(vol_name, user, user_token = nil)
      vol = bb_lookup_vol(vol_name, user, user_token)
      bbapi(user, user_token).objects.remove_by_xref("#{volume_ref_prefix}#{vol_name}", scope: "vdisk,xmd")
      if bbapi(user, user_token).vdisk.list(vss_id: vol.vss_id).empty?
        bbapi(user, user_token).vss.remove(vol.vss_id)
      end
    rescue Blockbridge::NotFound
    end

    def bb_lookup_user(user)
      raise Blockbridge::NotFound if bbapi.user_profile.list(login: user).length == 0
    end

    def bb_lookup_vol_info(vol)
      bb_lookup_user(vol[:user])
      info = bbapi.xmd.info("docker-volume-#{vol[:name]}")
      info[:data].merge(info[:data][:volume])
    rescue Excon::Errors::NotFound, Excon::Errors::Gone, Blockbridge::NotFound
    end

    def bb_host_attached(ref, user, user_token = nil)
      bbapi(user, user_token).xmd.info(ref)
    rescue Excon::Errors::NotFound
    end

    def bb_get_attached(vol_name, user, user_token = nil)
      vol = bb_lookup_vol(vol_name, user, user_token)
      attached = vol.xmd_refs.select { |x| x.start_with? "host-attach" }
      return unless attached.length > 0
      attached.map! { |ref|
        bb_host_attached(ref, user, user_token)
      }.compact!
      return unless attached.length > 0
      attached
    rescue Blockbridge::NotFound, Excon::Errors::NotFound
    end
  end
end
