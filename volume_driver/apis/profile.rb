# Copyright (c) 2015-2017, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

class API::Profile < Grape::API
  prefix 'profile'

  desc 'Create a profile'
  params do
    requires :name,         type: String,  desc: 'profile name'
    optional :user,         type: String,  desc: 'volume user (owner)'
    optional :capacity,     type: String,  desc: 'volume capacity'
    optional :type,         type: String,  desc: 'storage service type'
    optional :iops,         type: Integer, desc: 'volume provisioning IOPS (QoS)'
    optional :attributes,   type: String,  desc: 'volume attributes'
    optional :transport,    type: String,  desc: 'specify transport security (tls, insecure)', transport_type: true
    optional :s3,           type: String,  desc: 'S3 object store'
    optional :backup,       type: String,  desc: 'object backup'
    optional :access_token, type: String,  desc: 'API access token for user authentication'
  end
  post do
    status 201
    synchronize do
      body(profile_create)
    end
  end

  desc 'list profiles'
  get do
    body(profile_info)
  end

  route_param :name do
    desc 'Show a profile'
    get do
      body(profile_info params[:name])
    end

    desc 'Delete a profile'
    delete do
      status 204
      synchronize do
        profile_remove
      end
    end
  end
end
