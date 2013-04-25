module WinRM
  class FileManager 
    attr_reader :client
    attr_reader :opts

    def initialize(client)
      @client = client
      @opts ||= {}
    end

    def directory?(path)
      path = Path.new(path) unless path.is_a? Path
      response = client.wql "Select * From Win32_Directory Where Name = \"#{path.double_escaped_windows_path}\""
      not response.empty?
    end

    def file?(path)
      path = Path.new(path) unless path.is_a? Path
      response = client.wql "Select * From CIM_DataFile Where Name = \"#{path.double_escaped_windows_path}\""
      not response.empty?
    end

    def exists?(path)
      directory?(path) | file?(path)
    end

    def delete(path)
      path = Path.new(path) unless path.is_a? Path
      if exists? path
        r = WinRM::Request::InvokeWmi.new(client,wmi_class: 'CIM_DataFile', method: 'Delete', selectors: {Name: path.double_escaped_windows_path})
        r.execute
      else
        raise IOError, "Item does not exist #{path.windows_path}"
      end
    end

    def dir(path)
      path = Path.new(path) unless path.is_a? Path
      begin 
        items = client.wql("ASSOCIATORS OF {Win32_Directory=\"#{path.double_escaped_windows_path}\"} where  ResultClass=CIM_DataFile") + 
                  client.wql("ASSOCIATORS OF {Win32_Directory=\"#{path.double_escaped_windows_path}\"} where  ResultClass=CIM_Directory ResultRole = PartComponent")
        
        items
      rescue WinRM::WinRMHTTPTransportError
        if $!.detail[:msft_wmi_error] and $!.detail[:msft_wmi_error][:cim_status_code].to_i.eql? 6
          raise IOError, "Directory not found #{path.windows_path}"
        else
          raise
        end
      end
    end

    def send_file(local_file,remote_file, opts = {})
      default_opts = { overwrite: false }
      opts = default_opts.merge(opts)

      if exists?(remote_file)
        if opts[:overwrite].eql?(true)
          delete(remote_file)
        else
          raise StandardError, "File exists and you did not specify the overwrite option #{remote_file}"
        end
      end


      command_id = client.start_process(client.shell_id, command: 'Powershell -Command ^-', batch_mode: false, arguments: [] )
      
      output = StringIO.new

      #t = Thread.new do
      #  client.read_streams(client.shell_id,command_id, output, output )
      #  client.close_command(client.shell_id,command_id)
      #  output.rewind
      #  puts output.read
      #end

      client.write_stdin(client.shell_id,command_id, "if( Test-Path \"#{remote_file}\") { Remove-Item \"#{remote_file}\" } \r\n")

      File.open(local_file, 'rb') do |f|
        begin
          chunk = Base64.encode64(f.read(10200))
          chunk.gsub!("\n",'')
            client.write_stdin(client.shell_id,command_id, "Add-Content -Path \"#{remote_file}\" -Encoding byte -Value ([System.Convert]::FromBase64String(\"#{chunk.chomp}\"))\r\n")
            puts "Chunk Done"

        end until f.eof?
      end
      client.write_stdin(client.shell_id,command_id,"exit\r\n")
      true
    end

    def parse_bool(item)
      return true if item == true || item =~ (/(true|t|yes|y|1)$/i)
      return false if item == false || item.blank? || item =~ (/(false|f|no|n|0)$/i)
      raise ArgumentError.new("invalid value for Boolean: \"#{item}\"")
    end
  end
end
