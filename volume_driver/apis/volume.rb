# Copyright (c) 2015-2016, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

class API::Volume < Grape::API
  prefix 'volume'

  desc 'Create a volume'
  params do
    requires :name,         type: String,  desc: 'volume name'
    optional :profile,      type: String,  desc: 'volume profile'
    optional :type,         type: String,  desc: 'volume type', volume_type: true
    optional :user,         type: String,  desc: 'volume user (owner)'
    optional :otp,          type: String,  desc: 'volume one time password (OTP)'
    optional :tls,          type: Boolean, desc: 'attach with TLS transport security'
    optional :access_token, type: String,  desc: 'API access token for user authentication'
    optional :capacity,     type: String,  desc: 'volume capacity'
    optional :iops,         type: Integer, desc: 'volume provisioning IOPS (QoS)'
    optional :attributes,   type: String,  desc: 'volume attributes'
    optional :clone_basis,  type: String,  desc: '(autoclone) volume clone basis'
    optional :snapshot_tag, type: String,  desc: '(autoclone) volume clone basis snapshot tag'
    optional :snapshot_interval_hours, type: Integer, desc: '(snappy) take snapshot every interval'
    optional :snapshot_interval_history, type: Integer, desc: '(snappy) retrain this many snapshots'
    mutually_exclusive :profile, :type
  end
  post do
    status 201
    synchronize do
      volume_create
      body(volume_info)
    end
  end

  desc 'List all volumes'
  get do
    body(volume_lookup_all)
  end

  route_param :name do
    desc "Show a volume"
    get do
      body(volume_lookup)
    end

    desc 'Delete a volume'
    delete do
      status 204
      synchronize do
        volume_remove
      end
    end
  end
end
