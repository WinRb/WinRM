module WinRM
  class Client
    
    attr_reader :options
    attr_reader :endpoint
    attr_reader :service

    def initialize(endpoint, opts = {})
      default_opts = { protocol: :http }
      opts = default_opts.merge(opts)

      @endpoint = endpoint
      @service = Service.new(endpoint,opts)

    end

    def shell_id
      @shell_id ||= service.open_shell
    end

    def close
      if @shell_id
        service.close_shell(@shell_id)
        @shell_id = nil
      end
    end



     # Run a CMD command
    # @param [String] command The command to run on the remote system
    # @param [Array <String>] arguments arguments to the command
    # @return [Hash] :stdout and :stderr
    def cmd(command, arguments = [], opts = {})
      default_opts = { stdout: STDOUT, stderr: STDERR }
      opts = default_opts.merge(opts)
      command_id =  service.run_command(shell_id, command, arguments)
      command_output = service.get_command_output(shell_id, command_id) do |stdout, stderr|
        opts[:stdout].write stdout
        opts[:stderr].write stderr 
      end
      service.cleanup_command(shell_id, command_id)
      #close_shell(shell_id)
      command_output
    end


    # Run a Powershell script that resides on the local box.
    # @param [IO,String] script_file an IO reference for reading the Powershell script or the actual file contents
    # @return [Hash] :stdout and :stderr
    def powershell(script_file, opts = {})
      default_opts = { stdout: STDOUT, stderr: STDERR }
      opts = default_opts.merge(opts)

      # if an IO object is passed read it..otherwise assume the contents of the file were passed
      script = script_file.kind_of?(IO) ? script_file.read : script_file

      script = script.chars.to_a.join("\x00").chomp
      script << "\x00" unless script[-1].eql? "\x00"
      if(defined?(script.encode))
        script = script.encode('ASCII-8BIT')
        script = Base64.strict_encode64(script)
      else
        script = Base64.encode64(script).chomp
      end

      command_id = service.run_command(shell_id, "powershell -encodedCommand #{script}")
      command_output = service.get_command_output(shell_id, command_id)  do |stdout, stderr|
        opts[:stdout].write stdout
        opts[:stderr].write stderr 
      end

      service.cleanup_command(shell_id, command_id)
      #close_shell(shell_id)
      command_output
    end

    def wql(query)
      service.run_wql(query)
    end

  end
end