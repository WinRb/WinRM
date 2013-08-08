if GSSAPI::LibGSSAPI::GSSAPI_LIB_TYPE == :heimdal
  warn 'OSX will leak pointers. Please do not use as a long running process'
  module GSSAPI
    module LibGSSAPI
      class GssNameT < GssPointer
        def self.release_ptr(name_ptr)
          warn "Leaking #{name_ptr.address.to_s(16)}"
        end
      end

      class GssCtxIdT < GssPointer
        def self.release_ptr(context_ptr)
          warn "Leaking #{context_ptr.address.to_s(16)}"
        end
      end
    end
  end
end