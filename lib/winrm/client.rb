require "readline"
require 'base64'

module WinRM
  class Client

    attr_reader :httpcli
    attr_reader :endpoint
    attr_reader :host
    attr_reader :opts 

    # TODO: Disable basic and digest authentication
    def initialize(endpoint, opts = {})
      default_opts = { port: 5985, ssl: false, env_vars: {} }
      opts = default_opts.merge(opts)
      @opts = opts
      @host = host

      @httpcli = HTTPClient.new
      @httpcli.www_auth.instance_variable_set("@authenticator",[
          @httpcli.www_auth.negotiate_auth,
          @httpcli.www_auth.sspi_negotiate_auth
        ])
      

      transport = opts[:ssl].eql?(true) ? 'https' : 'https'
      transport = 'http'
      @endpoint = URI("#{transport}://#{endpoint}:#{opts[:port]}/wsman")
      
      opts[:endpoint] = @endpoint

      unless opts[:user] and opts[:pass]
        raise StandardError, 'Username and Password are required'
      end

      @httpcli.set_auth(@endpoint.to_s, opts[:user], opts[:pass])

      opts.delete(:user)
      opts.delete(:pass)
    end

    def ready?
      begin
        wql("Select * from Win32_Process")
        return true
      rescue HTTPClient::KeepAliveDisconnected
        return false
      end
    end

    def wql(query, wmi_namespace = nil)
      WinRM::Request::Wql.new(self, endpoint: endpoint, query: query, wmi_namespace: wmi_namespace).execute
    end
    
    def shell_id
      @shell_id ||= open_shell(env_vars: opts[:env_vars])
    end

    def cmd(command,arguments = '', opts= {})
      default_opts ={ streams_as_strings: false, stdout: STDOUT, stderr: STDERR }
      opts = default_opts.merge(opts)

      arguments = [arguments] unless arguments.is_a? Array

      begin
        command_id = start_process(shell_id, command: command, arguments: (arguments || []) )
        result = read_streams(shell_id,command_id, opts[:stdout], opts[:stderr])

        result.stdout.rewind unless is_tty(result.stdout)
        result.stderr.rewind unless is_tty(result.stderr)
        
        close_command(shell_id,command_id)
        
        return result.exit_code, (is_tty(result.stdout) ? nil : result.stdout), (is_tty(result.stderr) ? nil : result.stderr)
      rescue
        raise
      ensure
        begin 
          close_command(shell_id,command_id)
        rescue ; end
      end
    end

    def powershell(script,opts = {})
      script = script.kind_of?(IO) ? script.read : script
      script = script.chars.to_a.join("\x00").chomp
      script << "\x00" unless script[-1].eql? "\x00"
      script = script.encode('ASCII-8BIT')
      script = Base64.strict_encode64(script)
      cmd("powershell", "-encodedCommand #{script}", opts)
    end

    def disconnect
      close_shell(shell_id)
    end

    def shell(shell_name = :cmd)
      case shell_name
      when :cmd
        command = 'cmd'
      when :powershell
        command = "Powershell -Command ^-"
      else
        raise ArgumentError, "Invalid console type #{shell_name}"
      end

      process = start_process(shell_id,:command => command, batch_mode: false, :arguments => [])

      t = Thread.new do
        read_streams(shell_id,process, STDOUT, STDERR )
        close_command(shell_id,process)
        exit 0
      end

      Signal.trap("INT") do
        puts "Exiting..."
        exit 0
      end

      if shell_name.eql? :powershell
        write_stdin(shell_id,process, "Write-Host -NoNewline \"PS $(pwd)> \"\r\n")
      end

      while buf = Readline.readline('', true)
        if buf =~ /^exit!$/
          close_command(shell_id,process)
          exit 0
        else
          write_stdin(shell_id,process,"#{buf}\r\n")
          if shell_name.eql? :powershell
            write_stdin(shell_id,process, "Write-Host -NoNewline \"PS $(pwd)> \"\r\n")
          end
        end
      end

    end

    def send_message(message)
      WinRM.logger.debug "Message: #{Nokogiri::XML(message).to_xml}"
      hdr = {'Content-Type' => 'application/soap+xml;charset=UTF-8', 'Content-Length' => message.length}
      resp = @httpcli.post(endpoint, message, hdr)
      if(resp.status == 200)
        WinRM.logger.debug "Response #{Nokogiri::XML(resp.body).to_xml}"
        return resp.http_body.content
      else
        WinRM.logger.debug resp.http_body.content
        raise WinRMHTTPTransportError.new("Bad HTTP response returned from server (#{resp.status}).", resp)
      end
    end

    def is_tty(stream)
      stream.respond_to?('tty?') && stream.tty?
    end
    def open_shell(call_opts = {})
      call_opts = opts.merge(call_opts)
      WinRM::Request::OpenShell.new(self, call_opts).execute
    end

    def close_shell(shell_id, call_opts = {})
      call_opts = opts.merge(call_opts)
      call_opts[:shell_id] = shell_id
      WinRM::Request::CloseShell.new(self,call_opts).execute
    end

    def start_process(shell_id, call_opts = {})
      call_opts = opts.merge(call_opts)
      call_opts[:shell_id] = shell_id
      WinRM::Request::StartProcess.new(self,call_opts).execute
    end

    def close_command(shell_id,command_id)
      WinRM::Request::CloseCommand.new(self, shell_id: shell_id, command_id: command_id).execute
    end

    def read_streams(shell_id,command_id, stdout, stderr)
      WinRM::Request::ReadOutputStreams.new(self, shell_id: shell_id, command_id: command_id, stdout: stdout, stderr: stderr).execute
    end

    def write_stdin(shell_id,command_id, text)
      WinRM::Request::WriteStdin.new(self, shell_id: shell_id, command_id: command_id, text: text ).execute
    end
  end
end