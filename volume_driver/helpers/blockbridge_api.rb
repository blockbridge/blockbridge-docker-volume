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
        if user && (user_token.nil? || user_token == system_access_token)
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

    def bbapi(user = volume_user, user_token = volume_access_token, otp = nil)
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
      raise Blockbridge::NotFound, "No volume #{vol_name} found" if vols.empty?
      vols.first
    end

    def bb_remove_vol(vol_name, user, user_token = nil)
      vol = bb_lookup_vol(vol_name, user, user_token)
      bbapi(user, user_token).objects.remove_by_xref("#{volume_ref_prefix}#{vol_name}", scope: "vdisk,xmd")
      if bbapi(user, user_token).vdisk.list(vss_id: vol.vss_id).empty?
        bbapi(user, user_token).vss.remove(vol.vss_id)
      end
    rescue Excon::Errors::NotFound, Excon::Errors::Gone, Blockbridge::NotFound, Blockbridge::Api::NotFoundError
    end

    def bb_lookup_backups(s3, &blk)
      backups = []
      bbapi.obj_store.list_backups(s3.id, {}).each do |backup|
        backup.merge!({
          s3:   s3.label ? s3.label : s3.id,
          user: volume_user,
        })
        backups.push backup
        blk.call backup if blk
      end
      backups
    rescue => e
      logger.info "S3 #{s3.id} list backups failed: #{e.message}"
      []
    end

    def bb_lookup_backup(s3, backup_id)
      bb_lookup_backups(s3) do |backup|
        next unless backup[:id] == backup_id || backup[:label] == backup_id
        return backup
      end
      nil
    end

    def bb_lookup_s3(label, backup_id = nil)
      s3s = []
      s3_params = {}
      if label
        begin
          s3s.push bbapi.obj_store.info(label)
        rescue Blockbridge::Api::NotFoundError, Excon::Errors::NotFound, Excon::Errors::Gone
        end
      end
      if s3s.empty?
        s3_params[:label] = label if label
        s3s = bbapi.obj_store.list(s3_params)
      end
      raise Blockbridge::NotFound, "S3 object store #{label ? label.concat(' ') : ''}not found" if s3s.empty?
      unless backup_id
        if s3s.length > 1
          raise Blockbridge::Conflict, "More than one S3 object store found; please specify an S3 and/or backup name"
        end
        s3s.first
      else
        s3s.each do |s3|
          if (backup = bb_lookup_backup(s3, backup_id))
            return s3, backup
          end
        end
        raise Blockbridge::NotFound, "Backup #{backup_id} not found in S3 object store."
      end
    end

    def bb_backup_vol(vol)
      vdisk = bb_lookup_vol(vol[:name], vol[:user], volume_access_token)
      s3 = bb_lookup_s3(volume_params[:s3])
      params = { obj_store_id: s3.id, label: volume_params[:backup], snapshot_id: nil, async: true }
      bbapi.vdisk.backup(vdisk.id, params)
    end

    def bb_lookup_user(user)
      raise Blockbridge::NotFound if bbapi.user_profile.list(login: user).length == 0
    end

    def bb_lookup_vol_info(vol)
      bb_lookup_user(vol[:user])
      info = bbapi.xmd.info("docker-volume-#{vol[:name]}")
      info[:data].merge(info[:data][:volume])
    rescue Excon::Errors::NotFound, Excon::Errors::Gone, Blockbridge::NotFound, Blockbridge::Api::NotFoundError
    end

    def bb_host_attached(ref, user, user_token = nil)
      bbapi(user, user_token).xmd.info(ref)
    rescue Excon::Errors::NotFound, Excon::Errors::Gone, Blockbridge::NotFound, Blockbridge::Api::NotFoundError
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
    rescue Excon::Errors::NotFound, Excon::Errors::Gone, Blockbridge::NotFound, Blockbridge::Api::NotFoundError
    end

    def bb_vss_provision
      # set provisioning query params
      query_params = Hash.new.tap do |h|
        if volume_params[:capacity]
          h[:capacity] = volume_params[:capacity]
        end
        h[:iops] = volume_params[:iops] if volume_params[:iops]
        h.merge(parse_tag_query(volume_params[:attributes])) if volume_params[:attributes]
      end

      # create vss params
      vss_params = {
        query: query_params,
        vss: {
          label: vol_name,
          xref:  volume_ref_name,
        },
        disk: {
          create:         true,
          label:          vol_name,
          xref:           volume_ref_name,
          xmd_refs:       [ volume_ref_name ],
          set_size_limit: false,
          set_workload:   false,
        },
        xmd: {
          create:      true,
          ref:         volume_ref_name,
          xref:        volume_ref_name,
          xmd_refs:    [ vol_cache_ref, vol_hostinfo_ref ],
          exists_ok:   true,
          reservation: true,
          publish:     true,
          data: {
            group: {
              _schema:  "group",
              _publish: false,
              data: {
                label: vol_name,
              },
            },
            volume: volume_params,
          },
        },
      }

      # clone from backup
      if volume_params[:backup]
        s3, backup = bb_lookup_s3(volume_params[:s3], volume_params[:backup])
        vss_params[:disk][:obj_store_id] = s3.id
        vss_params[:disk][:backup_id]    = backup[:id]
        vss_params[:query][:capacity]    = backup[:capacity]
      else
        vss_params[:xmd][:tags] = [ 'unformatted' ]
      end

      # create the vss
      vss = bbapi.vss.create(vss_params)

      # setup scoped authorization for async remove
      authz_params = {
        scope: "v:o=#{vss.id} v:r=manage_targets v:r=manage_profiles v:r=remove_vss v:r=manage_internal_disks",
        xref:  volume_ref_name,
      }
      authz = bbapi.authorization.create(authz_params)

      # patch in the authz to the volume definition
      xmd_params = {
        mode: 'patch',
        data: [ { op: 'add', path: '/volume/scope_token', value: authz.access_token } ],
      }
      bbapi.xmd.update(volume_ref_name, xmd_params)
    rescue Blockbridge::Api::ExecutionError => e
      raise Blockbridge::CommandError, e.message
    end
  end
end
