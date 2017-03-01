# Copyright (c) 2015-2017, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

class API::DockerPlugin < Grape::API
  #version 'v1', using: :header, vendor: 'docker.plugins'

  before do
    status 200
    parse_params(params)
    start_iscsid
  end

  resource 'Plugin.Activate' do
    desc "Activate Volume Driver"
    post do
      body(Implements: ["VolumeDriver"])
      driver_init
    end
  end

  resource 'VolumeDriver.Create' do
    desc "Create a Volume"
    params do
      requires :Name,       type: String, desc: 'Volume Name'
      optional :Opts, type: Hash, desc: 'Volume Options' do
        optional :profile,      type: String,  desc: 'volume profile'
        optional :user,         type: String,  desc: 'volume user (owner)'
        optional :capacity,     type: String,  desc: 'volume provisioning capacity'
        optional :type,         type: String,  desc: 'storage service type',
        optional :iops,         type: Integer, desc: 'volume provisioning IOPS (QoS)'
        optional :attributes,   type: String,  desc: 'volume provisioning attributes'
        optional :transport,    type: String,  desc: 'specify transport security (tls, insecure)', transport_type: true
        optional :otp,          type: String,  desc: 'volume one time password (OTP)'
        optional :access_token, type: String,  desc: 'API access token for user authentication'
        optional :from_backup,  type: String,  desc: 'create volume from backup'
      end
    end
    post do
      synchronize do
        body(Err: nil)
        volume_check_params
        volume_create
        vol_cache_add
      end
    end
  end

  resource 'VolumeDriver.Remove' do
    desc "Remove a Volume"
    params do
      requires :Name, type: String, desc: 'Volume Name'
      optional :Opts, type: Hash, desc: 'Volume Options' do
        optional :otp, type: String,  desc: 'volume one time password (OTP)'
      end
    end
    post do
      synchronize do
        body(Err: nil)
        volume_remove(async: true)
      end
    end
  end

  resource 'VolumeDriver.Mount' do
    desc "Mount a Volume"
    params do
      requires :Name, type: String, desc: "Volume Name"
      optional :ID, type: String, desc: "Volume mount ID"
      optional :Opts, type: Hash, desc: 'Volume Options' do
        optional :otp, type: String,  desc: 'volume one time password (OTP)'
      end
    end
    post do
      synchronize do
        body(Mountpoint: mnt_path, Err: nil)
        volume_mount
        vol_cache_add
      end
    end
  end

  resource 'VolumeDriver.Path' do
    desc "Query path of a Volume"
    params do
      requires :Name, type: String, desc: "Volume Name"
    end
    post do
      body(Mountpoint: mnt_path_map, Err: nil)
      vol_cache_add
    end
  end

  resource 'VolumeDriver.Unmount' do
    desc "Unmount a Volume"
    params do
      requires :Name, type: String, desc: "Volume Name"
      optional :ID, type: String, desc: "Volume mount ID"
    end
    post do
      synchronize do
        body(Err: nil)
        volume_unmount
        vol_cache_add
      end
    end
  end

  resource 'VolumeDriver.Get' do
    desc 'Get volume info'
    params do
      requires :Name, type: String, desc: "Volume Name"
    end
    post do
      body(Volume: volume_get, Err: nil)
      vol_cache_add
    end
  end

  resource 'VolumeDriver.List' do
    desc "List existing volumes"
    post do
      body(Volumes: volume_list, Err: nil)
    end
  end

  resource 'VolumeDriver.Capabilities' do
    desc "Get driver capabilities"
    post do
      body(Capabilities: { "Scope" => "global" })
    end
  end
end
