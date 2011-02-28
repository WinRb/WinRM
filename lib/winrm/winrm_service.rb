module WinRM
  # This is the main class that does the SOAP request/response logic. There are a few helper classes, but pretty
  #   much everything comes through here first.
  class WinRMWebService

    DEFAULT_TIMEOUT = 'PT60S'
    DEFAULT_MAX_ENV_SIZE = 153600
    DEFAULT_LOCALE = 'en-US'

    # @param [String,URI] endpoint the WinRM webservice endpoint
    # @param [Symbol] transport either :kerberos(default)/:ssl/:plaintext
    # @param [Hash] opts Misc opts for the various transports.
    #   @see WinRM::HTTP::HttpTransport
    #   @see WinRM::HTTP::HttpGSSAPI
    #   @see WinRM::HTTP::HttpSSL
    def initialize(endpoint, transport = :kerberos, opts = {})
      @timeout = DEFAULT_TIMEOUT
      @max_env_sz = DEFAULT_MAX_ENV_SIZE 
      @locale = DEFAULT_LOCALE
      case transport
      when :kerberos
        # TODO: check fo keys and throw error if missing
        @xfer = HTTP::HttpGSSAPI.new(endpoint, opts[:realm], opts[:service], opts[:keytab])
      when :plaintext
        @xfer = HTTP::HttpPlaintext.new(endpoint, opts[:user], opts[:pass])
      when :ssl
        @xfer = HTTP::HttpSSL.new(endpoint, opts[:user], opts[:pass], opts[:ca_trust_path])
      end
    end

    # Operation timeout
    def op_timeout(sec)
      @timeout = Iso8601Duration.sec_to_dur(sec)
    end

    # Max envelope size
    def max_env_size(sz)
      @max_env_sz = sz
    end

    # Default locale
    def locale(locale)
      @locale = locale
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
        "#{NS_WSMAN_DMTF}:Option" => ['TRUE','FALSE'],
        :attributes! => {"#{NS_WSMAN_DMTF}:Option" => {'Name' => ['WINRS_CONSOLEMODE_STDIN','WINRS_SKIP_CMD_SHELL']}}}}
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
        next if n.text.nil? || n.text.empty?
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
        output[:exitcode] = (resp/"//#{NS_WIN_SHELL}:ExitCode").text.to_i
      end

      if block_given?
        yield output
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
    alias :cmd :run_cmd


    # Run a Powershell script that resides on the local box.
    # @param [IO,String] script_file an IO reference for reading the Powershell script or the actual file contents
    # @return [Hash] :stdout and :stderr
    def run_powershell_script(script_file)
      # if an IO object is passed read it..otherwise assume the contents of the file were passed
      script = script_file.kind_of?(IO) ? script_file.read : script_file

      script = script.chars.to_a.join("\x00").chomp
      if(defined?(script.encode))
        script = script.encode('ASCII-8BIT')
        script = Base64.strict_encode64(script)
      else
        script = Base64.encode64(script).chomp
      end


      shell_id = open_shell
      command_id = run_command(shell_id, "powershell -encodedCommand #{script}")
      command_output = get_command_output(shell_id, command_id)
      cleanup_command(shell_id, command_id)
      close_shell(shell_id)
      command_output
    end


    # Run a WQL Query
    # @see http://msdn.microsoft.com/en-us/library/aa394606(VS.85).aspx
    # @param [String] wql The WQL query
    # @return [Array<Hash>] Returns an array of Hashes that contain the key/value pairs returned from the query.
    def run_wql(wql)
      header = {}.merge(resource_uri_wmi).merge(action_enumerate)

      begin
        resp = invoke("#{NS_ENUM}:Enumerate", {:soap_action => :auto, :http_options => nil, :soap_header => header}) do |enum|
          enum.add("#{NS_WSMAN_DMTF}:OptimizeEnumeration")
          enum.add("#{NS_WSMAN_DMTF}:MaxElements",'32000')
          mattr = nil
          enum.add("#{NS_WSMAN_DMTF}:Filter", wql) do |filt|
            filt.set_attr('Dialect','http://schemas.microsoft.com/wbem/wsman/1/WQL')
          end
        end
      rescue Handsoap::Fault => e
        raise WinRMWebServiceError, e.reason
      end

      query_response = []
      (resp/"//#{NS_ENUM}:EnumerateResponse//#{NS_WSMAN_DMTF}:Items/*").each do |i|
        qitem = {}
        (i/'*').each do |si|
          qitem[si.node_name] = si.to_s
        end
        query_response << qitem
      end
      query_response
    end



    private

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
      { "#{NS_ADDRESSING}:To" => "#{@xfer.endpoint.to_s}",
        "#{NS_ADDRESSING}:ReplyTo" => {
        "#{NS_ADDRESSING}:Address" => 'http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous',
          :attributes! => {"#{NS_ADDRESSING}:Address" => {'mustUnderstand' => true}}},
        "#{NS_WSMAN_DMTF}:MaxEnvelopeSize" => @max_env_sz,
        "#{NS_ADDRESSING}:MessageID" => "uuid:#{UUID.generate.upcase}",
        "#{NS_WSMAN_DMTF}:Locale/" => '',
        "#{NS_WSMAN_MSFT}:DataLocale/" => '',
        "#{NS_WSMAN_DMTF}:OperationTimeout" => @timeout,
        :attributes! => {
          "#{NS_WSMAN_DMTF}:MaxEnvelopeSize" => {'mustUnderstand' => true},
          "#{NS_WSMAN_DMTF}:Locale/" => {'xml:lang' => @locale, 'mustUnderstand' => false},
          "#{NS_WSMAN_MSFT}:DataLocale/" => {'xml:lang' => @locale, 'mustUnderstand' => false}
        }}
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

    def send_message(message)
      @xfer.send_request(message)
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
end # WinRM

