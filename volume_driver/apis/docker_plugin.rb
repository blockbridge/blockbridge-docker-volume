# Copyright (c) 2015-2016, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

class API::DockerPlugin < Grape::API
  #version 'v1', using: :header, vendor: 'docker.plugins'

  before do
    status 200
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
      requires :Name,       type: String, desc: "Volume Name"
      optional :Opts, type: Hash, desc: "Volume Options" do
        optional :profile,      type: String,  desc: "volume profile"
        optional :type,         type: String,  desc: 'volume type', default: 'autovol', volume_type: true
        optional :user,         type: String,  desc: 'volume user (owner)'
        optional :capacity,     type: String,  desc: 'volume provisioning capacity'
        optional :iops,         type: Integer, desc: 'volume provisioning IOPS (QoS)'
        optional :attributes,   type: String,  desc: 'volume provisioning attributes'
        optional :clone_basis,  type: String,  desc: '(autoclone) volume clone basis'
        optional :snapshot_tag, type: String,  desc: '(autoclone) volume clone basis snapshot tag'
        optional :snapshot_interval_hours, type: Integer, desc: '(snappy) take snapshot every interval'
        optional :snapshot_interval_history, type: Integer, desc: '(snappy) snapshot retain count'
        mutually_exclusive :profile, :type
      end
    end
    post do
      synchronize do
        body(Err: nil)
        volume_check_params
        volume_create
      end
    end
  end

  resource 'VolumeDriver.Remove' do
    desc "Remove a Volume"
    params do
      requires :Name, type: String, desc: "Volume Name"
    end
    post do
      synchronize do
        body(Err: nil)
        volume_remove
      end
    end
  end

  resource 'VolumeDriver.Mount' do
    desc "Mount a Volume"
    params do
      requires :Name, type: String, desc: "Volume Name"
    end
    post do
      synchronize do
        body(Mountpoint: mnt_path, Err: nil)
        volume_mount
      end
    end
  end

  resource 'VolumeDriver.Path' do
    desc "Query path of a Volume"
    params do
      requires :Name, type: String, desc: "Volume Name"
    end
    post do
      body(Mountpoint: mnt_path, Err: nil)
    end
  end

  resource 'VolumeDriver.Unmount' do
    desc "Unmount a Volume"
    params do
      requires :Name, type: String, desc: "Volume Name"
    end
    post do
      synchronize do
        body(Err: nil)
        volume_unmount
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
    end
  end

  resource 'VolumeDriver.List' do
    desc "List existing volumes"
    post do
      body(Volumes: volume_list, Err: nil)
    end
  end
end
