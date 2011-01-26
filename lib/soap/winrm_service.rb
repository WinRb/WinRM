require 'httpclient'
require 'savon/soap/xml'
require 'uuid'
require 'gssapi'
require 'base64'
require 'nokogiri'

module WinRM
  module SOAP
    NS_ADDRESSING  ='a'   # http://schemas.xmlsoap.org/ws/2004/08/addressing
    NS_CIMBINDING  ='b'   # http://schemas.dmtf.org/wbem/wsman/1/cimbinding.xsd
    NS_ENUM        ='n'   # http://schemas.xmlsoap.org/ws/2004/09/enumeration
    NS_TRANSFER    ='x'   # http://schemas.xmlsoap.org/ws/2004/09/transfer
    NS_WSMAN_DMTF  ='w'   # http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd
    NS_WSMAN_MSFT  ='p'   # http://schemas.microsoft.com/wbem/wsman/1/wsman.xsd
    NS_SCHEMA_INST ='xsi' # http://www.w3.org/2001/XMLSchema-instance
    NS_WIN_SHELL   ='rsp' # http://schemas.microsoft.com/wbem/wsman/1/windows/shell
    NS_WSMAN_FAULT = 'f'  # http://schemas.microsoft.com/wbem/wsman/1/wsmanfault

    class WinRMWebService

      # @param [String,URI] endpoint the WinRM webservice endpoint
      def initialize(endpoint, transport = :kerberos, realm = nil)
        @endpoint = endpoint.is_a?(String) ? URI.parse(endpoint) : endpoint
        @httpcli = HTTPClient.new(:agent_name => 'Ruby WinRM Client')

        if(transport == :kerberos)
          @service = "HTTP/#{@endpoint.host}@#{realm}"
          init_krb
        end
      end

      # Create a Shell on the destination host
      # @param [String<optional>] i_stream Which input stream to open.  Leave this alone unless you know what you're doing
      # @param [String<optional>] o_stream Which output stream to open.  Leave this alone unless you know what you're doing
      # @return [String] The ShellId from the SOAP response.  This is our open shell instance on the remote machine.
      def open_shell(i_stream = 'stdin', o_stream = 'stdout stderr')
        s = Savon::SOAP::XML.new
        s.version = 2
        s.namespaces.merge!(namespaces)

        h_opts = { "#{NS_WSMAN_DMTF}:OptionSet" => { "#{NS_WSMAN_DMTF}:Option" => ['FALSE',437],
            :attributes! => {"#{NS_WSMAN_DMTF}:Option" => {'Name' => ['WINRS_NOPROFILE','WINRS_CODEPAGE']}}}}
        s.header.merge!(merge_headers(header,resource_uri_cmd,action_create,h_opts))

        s.input = "#{NS_WIN_SHELL}:Shell"
        s.body = { "#{NS_WIN_SHELL}:InputStreams" => i_stream,
          "#{NS_WIN_SHELL}:OutputStreams" => o_stream}

        resp = send_message(s.to_xml)

        (resp/"//*[@Name='ShellId']").text
      end

      # Run a command on a machine with an open shell
      # @param [String] shell_id The shell id on the remote machine.  See #open_shell
      # @param [String] command The command to run on the remote machine
      # @return [String] The CommandId from the SOAP response.  This is the ID we need to query in order to get output.
      def run_command(shell_id, command)
        s = Savon::SOAP::XML.new
        s.version = 2
        s.namespaces.merge!(namespaces)
        h_opts = { "#{NS_WSMAN_DMTF}:OptionSet" => {
          "#{NS_WSMAN_DMTF}:Option" => ['TRUE'],
            :attributes! => {"#{NS_WSMAN_DMTF}:Option" => {'Name' => ['WINRS_CONSOLEMODE_STDIN']}}}}
        s.header.merge!(merge_headers(header,resource_uri_cmd,action_command,h_opts,selector_shell_id(shell_id)))
        s.input = "#{NS_WIN_SHELL}:CommandLine"
        s.body = { "#{NS_WIN_SHELL}:Command" => "\"#{command}\"" }
        resp = send_message(s.to_xml)

        (resp/"//#{NS_WIN_SHELL}:CommandId").text
      end
      
      # Get the Output of the given shell and command
      # @param [String] shell_id The shell id on the remote machine.  See #open_shell
      # @param [String] command_id The command id on the remote machine.  See #run_command
      # @return [Hash] Returns a Hash with a key :exitcode and :data.  Data is an Array of Hashes where the cooresponding key
      #   is either :stdout or :stderr.  The reason it is in an Array so so we can get the output in the order it ocurrs on
      #   the console.
      def get_command_output(shell_id, command_id)
        s = Savon::SOAP::XML.new
        s.version = 2
        s.namespaces.merge!(namespaces)
        s.header.merge!(merge_headers(header,resource_uri_cmd,action_receive,selector_shell_id(shell_id)))

        s.input = "#{NS_WIN_SHELL}:Receive"

        s.body = { "#{NS_WIN_SHELL}:DesiredStream" => 'stdout stderr',
          :attributes! => {"#{NS_WIN_SHELL}:DesiredStream" => {'CommandId' => command_id}}}

        resp = send_message(s.to_xml)

        output = {:data => []}
        (resp/"//#{NS_WIN_SHELL}:Stream").each do |n|
          next if n.text.nil?
          output[:data] << {n['Name'].to_sym => Base64.decode64(n.text)}
        end

        # We may need to get additional output if the stream has not finished.
        # The CommandState will change from Running to Done like so:
        # @example
        #   from...
        #   <rsp:CommandState CommandId="495C3B09-E0B0-442A-9958-83B529F76C2C" State="http://schemas.microsoft.com/wbem/wsman/1/windows/shell/CommandState/Running"/>
        #   to...
        #   <rsp:CommandState CommandId="495C3B09-E0B0-442A-9958-83B529F76C2C" State="http://schemas.microsoft.com/wbem/wsman/1/windows/shell/CommandState/Done">
        #     <rsp:ExitCode>0</rsp:ExitCode>
        #   </rsp:CommandState>
        if((resp/"//#{NS_WIN_SHELL}:ExitCode").empty?)
          output.merge!(get_command_output(shell_id,command_id)) do |key, old_data, new_data|
            old_data += new_data
          end
        else
          output[:exitcode] = (resp/"//#{NS_WIN_SHELL}:ExitCode")
        end
        output
      end

      # Clean-up after a command.
      # @see #run_command
      # @param [String] shell_id The shell id on the remote machine.  See #open_shell
      # @param [String] command_id The command id on the remote machine.  See #run_command
      # @return [true] This should have more error checking but it just returns true for now.
      def cleanup_command(shell_id, command_id)
        s = Savon::SOAP::XML.new
        s.version = 2
        s.namespaces.merge!(namespaces)
        s.header.merge!(merge_headers(header,resource_uri_cmd,action_signal,selector_shell_id(shell_id)))

        # Signal the Command references to terminate (close stdout/stderr)
        s.input = ["#{NS_WIN_SHELL}:Signal", {'CommandId' => command_id}]

        s.body = { "#{NS_WIN_SHELL}:Code" => 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/signal/terminate' }
        resp = send_message(s.to_xml)
        true
      end

      # Close the shell
      # @param [String] shell_id The shell id on the remote machine.  See #open_shell
      # @return [true] This should have more error checking but it just returns true for now.
      def close_shell(shell_id)
        s = Savon::SOAP::XML.new
        s.version = 2
        s.namespaces.merge!(namespaces)
        s.namespaces.merge!(Savon::SOAP::XML::SchemaTypes)
        s.header.merge!(merge_headers(header,resource_uri_cmd,action_delete,selector_shell_id(shell_id)))

        # Because Savon does not support a nil Body we have to build it ourselves.
        s.xml do |b|
          b.tag!('env:Envelope', s.namespaces) do
            b.tag!('env:Header') do |bh|
              bh << Gyoku.xml(s.header) unless s.header.empty?
            end
            if(s.input.nil?)
              b.tag! 'env:Body'
            else
              b.tag! 'env:Body' do |bb|
                bb.tag! s.input do |bbb|
                  bbb << Gyoku.xml(s.body) if s.body
                end
              end
            end
          end
        end

        resp = send_message(s.to_xml)

        resp.remove_namespaces!
        (resp/"//Fault").empty?
      end

      # Run a CMD command
      # @param [String] command The command to run on the remote system
      # @return [Hash] :stdout and :stderr
      def run_cmd(command)
        shell_id = open_shell
        command_id =  run_command(shell_id, command)
        command_output = get_command_output(shell_id, command_id)
        cleanup_command(shell_id, command_id)
        close_shell(shell_id)
        command_output
      end


      private

      def init_krb
        @gsscli = GSSAPI::Simple.new(@endpoint.host, @service)
        token = @gsscli.init_context
        auth = Base64.strict_encode64 token

        ext_head = {"Authorization" => "Kerberos #{auth}",
          "Connection" => "Keep-Alive",
          "Content-Type" => "application/soap+xml;charset=UTF-8"
        }
        r = @httpcli.post(@endpoint, '', ext_head)
        itok = r.header["WWW-Authenticate"].pop
        itok = itok.split.last
        itok = Base64.strict_decode64(itok)
        @gsscli.init_context(itok)
      end

      def namespaces
        {'xmlns:a' => 'http://schemas.xmlsoap.org/ws/2004/08/addressing',
          'xmlns:b' => 'http://schemas.dmtf.org/wbem/wsman/1/cimbinding.xsd',
          'xmlns:n' => 'http://schemas.xmlsoap.org/ws/2004/09/enumeration',
          'xmlns:x' => 'http://schemas.xmlsoap.org/ws/2004/09/transfer',
          'xmlns:w' => 'http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd',
          'xmlns:p' => 'http://schemas.microsoft.com/wbem/wsman/1/wsman.xsd',
          'xmlns:rsp' => 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell'}
      end

      def header
        { "#{NS_ADDRESSING}:To" => "#{@endpoint.to_s}",
          "#{NS_ADDRESSING}:ReplyTo" => {
          "#{NS_ADDRESSING}:Address" => 'http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous',
            :attributes! => {"#{NS_ADDRESSING}:Address" => {'mustUnderstand' => true}}},
          "#{NS_WSMAN_DMTF}:MaxEnvelopeSize" => 153600,
          "#{NS_ADDRESSING}:MessageID" => "uuid:#{UUID.generate.upcase}",
          "#{NS_WSMAN_DMTF}:Locale/" => '',
          "#{NS_WSMAN_MSFT}:DataLocale/" => '',
          "#{NS_WSMAN_DMTF}:OperationTimeout" => 'PT60S',
          :attributes! => {
            "#{NS_WSMAN_DMTF}:MaxEnvelopeSize" => {'mustUnderstand' => true},
            "#{NS_WSMAN_DMTF}:Locale/" => {'xml:lang' => 'en-US', 'mustUnderstand' => false},
            "#{NS_WSMAN_MSFT}:DataLocale/" => {'xml:lang' => 'en-US', 'mustUnderstand' => false}
          }}
      end

      # @return [String] the encrypted request string
      def winrm_encrypt(str)
        iov_cnt = 2
        iov = FFI::MemoryPointer.new(GSSAPI::LibGSSAPI::GssIOVBufferDesc.size * iov_cnt)

        iov0 = GSSAPI::LibGSSAPI::GssIOVBufferDesc.new(FFI::Pointer.new(iov.address))
        iov0[:type] = (GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_TYPE_HEADER | GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_FLAG_ALLOCATE)

        iov1 = GSSAPI::LibGSSAPI::GssIOVBufferDesc.new(FFI::Pointer.new(iov.address + (GSSAPI::LibGSSAPI::GssIOVBufferDesc.size * 1)))
        iov1[:type] =  (GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_TYPE_DATA)
        iov1[:buffer].value = str

        conf_state = FFI::MemoryPointer.new :uint32
        min_stat = FFI::MemoryPointer.new :uint32

        maj_stat = GSSAPI::LibGSSAPI.gss_wrap_iov(min_stat, @gsscli.context, 1, 0, conf_state, iov, iov_cnt)

        #puts "MAJ WRAP: #{maj_stat}"
        #puts "MAJ WRAP: #{GSSAPI::LibGSSAPI::GSS_C_ROUTINE_ERRORS[maj_stat]}"
        #puts "MIN WRAP: #{min_stat.read_int}"
        #puts "CONF_STATE: #{conf_state.read_int}"

        token = [iov0[:buffer].length].pack('L')
        token += iov0[:buffer].value
        token += iov1[:buffer].value
      end


      # @return [String] the unencrypted response string
      def winrm_decrypt(str)
        iov_cnt = 2
        iov = FFI::MemoryPointer.new(GSSAPI::LibGSSAPI::GssIOVBufferDesc.size * iov_cnt)

        iov0 = GSSAPI::LibGSSAPI::GssIOVBufferDesc.new(FFI::Pointer.new(iov.address))
        iov0[:type] = (GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_TYPE_HEADER | GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_FLAG_ALLOCATE)

        iov1 = GSSAPI::LibGSSAPI::GssIOVBufferDesc.new(FFI::Pointer.new(iov.address + (GSSAPI::LibGSSAPI::GssIOVBufferDesc.size * 1)))
        iov1[:type] =  (GSSAPI::LibGSSAPI::GSS_IOV_BUFFER_TYPE_DATA)

        str.force_encoding('BINARY')
        str.sub!(/^.*Content-Type: application\/octet-stream\r\n(.*)--Encrypted.*$/m, '\1')

        len = str.unpack("L").first
        iov_data = str.unpack("LA#{len}A*")
        iov0[:buffer].value = iov_data[1]
        iov1[:buffer].value = iov_data[2]

        min_stat = FFI::MemoryPointer.new :uint32
        conf_state = FFI::MemoryPointer.new :uint32
        conf_state.write_int(1)
        qop_state = FFI::MemoryPointer.new :uint32
        qop_state.write_int(0)

        maj_stat = GSSAPI::LibGSSAPI.gss_unwrap_iov(min_stat, @gsscli.context, conf_state, qop_state, iov, iov_cnt)

        Nokogiri::XML(iov1[:buffer].value)
      end

      def send_message(msg)
        original_length = msg.length
        emsg = winrm_encrypt(msg)
        ext_head = {
          "Connection" => "Keep-Alive",
          "Content-Type" => "multipart/encrypted;protocol=\"application/HTTP-Kerberos-session-encrypted\";boundary=\"Encrypted Boundary\""
        }

        body = <<-EOF
--Encrypted Boundary\r
Content-Type: application/HTTP-Kerberos-session-encrypted\r
OriginalContent: type=application/soap+xml;charset=UTF-8;Length=#{original_length}\r
--Encrypted Boundary\r
Content-Type: application/octet-stream\r
#{emsg}--Encrypted Boundary\r
        EOF

        r = @httpcli.post(@endpoint, body, ext_head)

        winrm_decrypt(r.body.content)
      end



      # merge the various header hashes and make sure we carry all of the attributes
      #   through instead of overwriting them.
      def merge_headers(*headers)
        hdr = {}
        headers.each do |h|
          hdr.merge!(h) do |k,v1,v2|
            v1.merge!(v2) if k == :attributes!
          end
        end
        hdr
      end


      # Helper methods for SOAP Headers

      def resource_uri_cmd
        {"#{NS_WSMAN_DMTF}:ResourceURI" => 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/cmd',
          :attributes! => {"#{NS_WSMAN_DMTF}:ResourceURI" => {'mustUnderstand' => true}}}
      end

      def resource_uri_wmi(namespace = 'root/cimv2/*')
        {"#{NS_WSMAN_DMTF}:ResourceURI" => "http://schemas.microsoft.com/wbem/wsman/1/wmi/#{namespace}",
          :attributes! => {"#{NS_WSMAN_DMTF}:ResourceURI" => {'mustUnderstand' => true}}}
      end

      def action_create
        {"#{NS_ADDRESSING}:Action" => 'http://schemas.xmlsoap.org/ws/2004/09/transfer/Create',
          :attributes! => {"#{NS_ADDRESSING}:Action" => {'mustUnderstand' => true}}}
      end

      def action_delete
        {"#{NS_ADDRESSING}:Action" => 'http://schemas.xmlsoap.org/ws/2004/09/transfer/Delete',
          :attributes! => {"#{NS_ADDRESSING}:Action" => {'mustUnderstand' => true}}}
      end

      def action_command
        {"#{NS_ADDRESSING}:Action" => 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/Command',
          :attributes! => {"#{NS_ADDRESSING}:Action" => {'mustUnderstand' => true}}}
      end

      def action_receive
        {"#{NS_ADDRESSING}:Action" => 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/Receive',
          :attributes! => {"#{NS_ADDRESSING}:Action" => {'mustUnderstand' => true}}}
      end

      def action_signal
        {"#{NS_ADDRESSING}:Action" => 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/Signal',
          :attributes! => {"#{NS_ADDRESSING}:Action" => {'mustUnderstand' => true}}}
      end

      def action_enumerate
        {"#{NS_ADDRESSING}:Action" => 'http://schemas.xmlsoap.org/ws/2004/09/enumeration/Enumerate',
          :attributes! => {"#{NS_ADDRESSING}:Action" => {'mustUnderstand' => true}}}
      end

      def selector_shell_id(shell_id)
        {"#{NS_WSMAN_DMTF}:SelectorSet" => 
          {"#{NS_WSMAN_DMTF}:Selector" => shell_id, :attributes! => {"#{NS_WSMAN_DMTF}:Selector" => {'Name' => 'ShellId'}}}
        }
      end

    end # WinRMWebService
  end # SOAP
end # WinRM

