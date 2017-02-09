# Copyright (c) 2015-2017, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

module Blockbridge
  class Error < StandardError
    attr_reader :errors                                                                                
    attr_reader :status
    def initialize(message = nil, opts = {})                                                           
      @errors = opts[:errors]                                                                          
      @status = opts[:status]                                                                          
      super(message)
    end                                                                                                
  end
  class ClientError < Error; end
  class ServerError < Error; end                                                                       
  class NotFound < Error; end                                                                          
  class Conflict < Error; end
  class MissingKey < Error; end                                                                        
  class InternalError < Error; end                                                                     
  class ServiceUnavailable < Error; end                                                                
  class CommandError < Error; end
  class ResourcesUnavailable < Error; end
  class VolumeInuse < Error; end
  class RuntimeError < Error; end
  class RuntimeSuccess < Error; end
end
