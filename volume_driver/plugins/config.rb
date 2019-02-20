# Copyright (c) 2015-2017, Blockbridge Networks LLC.  All rights reserved.  Use
# of this source code is governed by a BSD-style license, found in the LICENSE
# file.

module Blockbridge
  class Config
    include Helpers
    attr_reader :config
    attr_reader :logger
    attr_reader :status

    def self.access_token
      @@access_token
    end

    def self.api_host
      @@api_host
    end

    def initialize(address, port, config, status, logger)
      @config = config
      @logger = logger
      @status = status
      @@access_token = nil
      @@api_host = nil
    end

    def run
      return if system_access_token != access_token_default
      logger.debug "Configuring authentication"
      net = bbapi.net.list({}).first
      return unless net[:nat_addr]
      return unless bbapi.status.authorization&.dig('permissions','user','rights','manage_authorizations')
      authz = bbapi.authorization.create({})
      status = bbapi.status.authorization
      @@access_token = authz[:access_token]
      @@api_host  = net[:nat_addr]
    rescue => e
      msg = e.message.chomp.squeeze("\n")
      msg.each_line do |m| logger.error "config: #{m.chomp}" end
      #e.backtrace.each do |b| logger.error(b) end
    end
  end
end
