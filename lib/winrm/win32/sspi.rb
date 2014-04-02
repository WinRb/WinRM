
require 'winrm/helpers/assert_patch'

def validate_patch
  # The code below patches the Win32::SSPI module from ruby core to add support
  # for encrypt/decrypt as described below.
  # Add few restrictions to make sure the patched methods are still
  # available, but still give a way to consciously use later versions
  PatchAssertions.assert_arity_of_patched_method(Win32::SSPI::NegotiateAuth, "initialize", -1)
  PatchAssertions.assert_arity_of_patched_method(Win32::SSPI::NegotiateAuth, "complete_authentication", 1)
  PatchAssertions.assert_arity_of_patched_method(Win32::SSPI::NegotiateAuth, "get_credentials", 0)
end

# Perform the patch validations
validate_patch

# Overrides and enhances the ruby core win32 sspi module to add support to
# encrypt/decrypt data to be sent over channel, example using SSP Negotiate auth

module Win32
  module SSPI
    # QueryContextAttributes attributes flags
    SECPKG_ATTR_SIZES = 0x00000000

    module API
      QueryContextAttributes = Win32API.new("secur32", "QueryContextAttributes", 'pLp', 'L')
      EncryptMessage = Win32API.new("secur32", "EncryptMessage", 'pLpL', 'L')
      DecryptMessage = Win32API.new("secur32", "DecryptMessage", 'ppLp', 'L')
    end

    class SecPkgContext_Sizes
      attr_accessor :cbMaxToken, :cbMaxSignature, :cbBlockSize, :cbSecurityTrailer

      def initialize
        @cbMaxToken = @cbMaxSignature = @cbBlockSize = @cbSecurityTrailer = 0
      end

      def cbMaxToken
        @cbMaxToken = @struct.unpack("LLLL")[0] if @struct
      end

      def cbMaxSignature
        @cbMaxSignature = @struct.unpack("LLLL")[1] if @struct
      end

      def cbBlockSize
        @cbBlockSize = @struct.unpack("LLLL")[2] if @struct
      end

      def cbSecurityTrailer
        @cbSecurityTrailer = @struct.unpack("LLLL")[3] if @struct
      end

      def to_p
        @struct ||= [@cbMaxToken, @cbMaxSignature, @cbBlockSize, @cbSecurityTrailer].pack("LLLL")
      end
    end

    #  SecurityBuffer for data to be encrypted
    class EncryptedSecurityBuffer

      SECBUFFER_DATA = 0x1    # Security buffer data
      SECBUFFER_TOKEN = 0x2   # Security token
      SECBUFFER_VERSION = 0

      def initialize(data_buffer, sizes)
        @original_msg_len = data_buffer.length
        @cbSecurityTrailer = sizes.cbSecurityTrailer
        @data_buffer = data_buffer
        @security_trailer = "\0" * sizes.cbSecurityTrailer
      end

      def to_p
        # Assumption is that when to_p is called we are going to get a packed structure. Therefore,
        # set @unpacked back to nil so we know to unpack when accessors are next accessed.
        @unpacked = nil
        # Assignment of inner structure to variable is very important here. Without it,
        # will not be able to unpack changes to the structure. Alternative, nested unpacks,
        # does not work (i.e. @struct.unpack("LLP12")[2].unpack("LLP12") results in "no associated pointer")
        @sec_buffer = [@original_msg_len, SECBUFFER_DATA, @data_buffer, @cbSecurityTrailer, SECBUFFER_TOKEN, @security_trailer].pack("LLPLLP")
        @struct ||= [SECBUFFER_VERSION, 2, @sec_buffer].pack("LLP")
      end

      def buffer
        unpack
        @buffer
      end

    private

      # Unpacks the SecurityBufferDesc structure into member variables. We
      # only want to do this once per struct, so the struct is deleted
      # after unpacking.
      def unpack
        if ! @unpacked && @sec_buffer && @struct
          dataBufferSize, dType, dataBuffer, tokenBufferSize, tType, tokenBuffer = @sec_buffer.unpack("LLPLLP")
          dataBufferSize, dType, dataBuffer, tokenBufferSize, tType, tokenBuffer = @sec_buffer.unpack("LLP#{dataBufferSize}LLP#{tokenBufferSize}")
          # Form the buffer stream as required by server
          @buffer = [tokenBufferSize].pack("L")
          @buffer << tokenBuffer << dataBuffer
          @struct = nil
          @sec_buffer = nil
          @unpacked = true
        end
      end
    end

    class DecryptedSecurityBuffer

      SECBUFFER_DATA = 0x1    # Security buffer data
      SECBUFFER_TOKEN = 0x2   # Security token
      SECBUFFER_VERSION = 0

      def initialize(buffer)
        # unpack to extract the msg and token
        token_size, token_buffer, enc_buffer = buffer.unpack("L")
        @original_msg_len = buffer.length - token_size - 4
        @cbSecurityTrailer, @security_trailer, @data_buffer = buffer.unpack("La#{token_size}a#{@original_msg_len}")
      end

      def to_p
        # Assumption is that when to_p is called we are going to get a packed structure. Therefore,
        # set @unpacked back to nil so we know to unpack when accessors are next accessed.
        @unpacked = nil
        # Assignment of inner structure to variable is very important here. Without it,
        # will not be able to unpack changes to the structure. Alternative, nested unpacks,
        # does not work (i.e. @struct.unpack("LLP12")[2].unpack("LLP12") results in "no associated pointer")
        @sec_buffer = [@original_msg_len, SECBUFFER_DATA, @data_buffer, @cbSecurityTrailer, SECBUFFER_TOKEN, @security_trailer].pack("LLPLLP")
        @struct ||= [SECBUFFER_VERSION, 2, @sec_buffer].pack("LLP")
      end

      def buffer
        unpack
        @buffer
      end

    private

      # Unpacks the SecurityBufferDesc structure into member variables. We
      # only want to do this once per struct, so the struct is deleted
      # after unpacking.
      def unpack
        if ! @unpacked && @sec_buffer && @struct
          dataBufferSize, dType, dataBuffer, tokenBufferSize, tType, tokenBuffer = @sec_buffer.unpack("LLPLLP")
          dataBufferSize, dType, dataBuffer, tokenBufferSize, tType, tokenBuffer = @sec_buffer.unpack("LLP#{dataBufferSize}LLP#{tokenBufferSize}")
          @buffer = dataBuffer
          @struct = nil
          @sec_buffer = nil
          @unpacked = true
        end
      end
    end

    class NegotiateAuth
      # Override to remember password
      # Creates a new instance ready for authentication as the given user in the given domain.
      # Defaults to current user and domain as defined by ENV["USERDOMAIN"] and ENV["USERNAME"] if
      # no arguments are supplied.
      def initialize(user = nil, domain = nil, password = nil)
        if user.nil? && domain.nil? && ENV["USERNAME"].nil? && ENV["USERDOMAIN"].nil?
          raise "A username or domain must be supplied since they cannot be retrieved from the environment"
        end
        @user = user || ENV["USERNAME"]
        @domain = domain || ENV["USERDOMAIN"]
        @password = password
      end

      # Takes a token and gets the next token in the Negotiate authentication chain. Token can be Base64 encoded or not.
      # The token can include the "Negotiate" header and it will be stripped.
      # Does not indicate if SEC_I_CONTINUE or SEC_E_OK was returned.
      # Token returned is Base64 encoded w/ all new lines removed.
      def complete_authentication(token)
        raise "This object is no longer usable because its resources have been freed." if @cleaned_up

        # Nil token OK, just set it to empty string
        token = "" if token.nil?

        if token.include? "Negotiate"
          # If the Negotiate prefix is passed in, assume we are seeing "Negotiate <token>" and get the token.
          token = token.split(" ").last
        end

        if token.include? B64_TOKEN_PREFIX
          # indicates base64 encoded token
          token = token.strip.unpack("m")[0]
        end

        outputBuffer = SecurityBuffer.new
        result = SSPIResult.new(API::InitializeSecurityContext.call(@credentials.to_p, @context.to_p, nil,
          REQUEST_FLAGS, 0, SECURITY_NETWORK_DREP, SecurityBuffer.new(token).to_p, 0,
          @context.to_p,
          outputBuffer.to_p, @contextAttributes, TimeStamp.new.to_p))

        if result.ok? then
          @auth_successful = true
          return encode_token(outputBuffer.token)
        else
          raise "Error: #{result.to_s}"
        end
      ensure
        # need to make sure we don't clean up if we've already cleaned up.
        # XXX - clean up later since encrypt/decrypt needs this
        # clean_up unless @cleaned_up
      end

      def encrypt_payload(body)
        if @auth_successful
          # Approach - http://msdn.microsoft.com/en-us/magazine/cc301890.aspx
          sizes = SecPkgContext_Sizes.new
          result = SSPIResult.new(API::QueryContextAttributes.call(@context.to_p, SECPKG_ATTR_SIZES, sizes.to_p))

          outputBuffer = EncryptedSecurityBuffer.new(body, sizes)
          result = SSPIResult.new(API::EncryptMessage.call(@context.to_p, 0, outputBuffer.to_p, 0 ))
          encrypted_msg = outputBuffer.buffer

          body = <<-EOF
--Encrypted Boundary\r
Content-Type: application/HTTP-SPNEGO-session-encrypted\r
OriginalContent: type=application/soap+xml;charset=UTF-8;Length=#{encrypted_msg.length - sizes.cbSecurityTrailer - 4}\r
--Encrypted Boundary\r
Content-Type: application/octet-stream\r
#{encrypted_msg}--Encrypted Boundary\r
EOF
        end
        body
      end

      def decrypt_payload(body)
        if @auth_successful

          matched_data = /--Encrypted Boundary\s+Content-Type:\s+application\/HTTP-SPNEGO-session-encrypted\s+OriginalContent:\s+type=\S+Length=(\d+)\s+--Encrypted Boundary\s+Content-Type:\s+application\/octet-stream\s+([\S\s]+)--Encrypted Boundary/.match(body)
          encrypted_msg = matched_data[2]

          outputBuffer = DecryptedSecurityBuffer.new(encrypted_msg)
          result = SSPIResult.new(API::DecryptMessage.call(@context.to_p, outputBuffer.to_p, 0, 0 ))
          body = outputBuffer.buffer
        end
        body
      end

      private
      # ** Override to add password support
      # Gets credentials based on user, domain or both. If both are nil, an error occurs
      def get_credentials
        @credentials = CredHandle.new
        ts = TimeStamp.new
        @identity = Identity.new @user, @domain, @password
        result = SSPIResult.new(API::AcquireCredentialsHandle.call(nil, "Negotiate", SECPKG_CRED_OUTBOUND, nil, @identity.to_p,
          nil, nil, @credentials.to_p, ts.to_p))
        raise "Error acquire credentials: #{result}" unless result.ok?
      end
    end
  end
end