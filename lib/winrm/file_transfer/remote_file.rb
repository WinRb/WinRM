require 'io/console'
require 'json'

module WinRM
  class RemoteFile

    attr_reader :local_path
    attr_reader :remote_path
    attr_reader :closed
    attr_reader :options

    def initialize(service, local_path, remote_path)
      @logger = Logging.logger[self]
      @closed = false
      @service = service
      @shell = service.open_shell
      @local_path = local_path
      @remote_path = full_remote_path(local_path, remote_path)
      @logger.debug("Creating RemoteFile of local '#{local_path}' at '#{@remote_path}'")
    ensure
      if !shell.nil?
        ObjectSpace.define_finalizer( self, self.class.close(shell, service) )
      end
    end

    def upload(&block)
      raise WinRMUploadError.new("This RemoteFile is closed.") if closed
      raise WinRMUploadError.new("Cannot find path: '#{local_path}'") unless File.exist?(local_path)

      @remote_path, should_upload = powershell_batch do | builder |
        builder << resolve_remote_command
        builder << is_dirty_command
      end

      if should_upload
        size = upload_to_remote(&block)
        powershell_batch {|builder| builder << create_post_upload_command}
      else
        size = 0
        logger.debug("Files are equal. Not copying #{local_path} to #{remote_path}")
      end
      size
    end
    
    def close
      service.close_shell(shell) unless shell.nil? or closed
      @closed = true
    end

    protected

    attr_reader :logger
    attr_reader :service
    attr_reader :shell

    def self.close(shell_id, service)
      proc { service.close_shell(shell_id) }
    end

    def full_remote_path(local_path, remote_path)
      base_file_name = File.basename(local_path)
      if File.basename(remote_path) != base_file_name
        remote_path = File.join(remote_path, base_file_name)
      end
      remote_path
    end

    def resolve_remote_command
      <<-EOH
        $dest_file_path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("#{remote_path}")

        if (!(Test-Path $dest_file_path)) {
          $dest_dir = ([System.IO.Path]::GetDirectoryName($dest_file_path))
          New-Item -ItemType directory -Force -Path $dest_dir | Out-Null
        }

        $dest_file_path
      EOH
    end

    def is_dirty_command
      local_md5 = Digest::MD5.file(local_path).hexdigest
      <<-EOH
        $dest_file_path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("#{remote_path}")

        if (Test-Path $dest_file_path) {
          $crypto_prov = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
          try {
            $file = [System.IO.File]::Open($dest_file_path,
              [System.IO.Filemode]::Open, [System.IO.FileAccess]::Read)
            $guest_md5 = ([System.BitConverter]::ToString($crypto_prov.ComputeHash($file)))
            $guest_md5 = $guest_md5.Replace("-","").ToLower()
          }
          finally {
            $file.Dispose()
          }
          if ($guest_md5 -eq '#{local_md5}') {
            return $false
          }
        }
        if(Test-Path $dest_file_path){remove-item $dest_file_path -Force}
        return $true
      EOH
    end

    def upload_to_remote(&block)
      logger.debug("Uploading '#{local_path}' to temp file '#{remote_path}'")
      base64_host_file = Base64.encode64(IO.binread(local_path)).gsub("\n", "")
      base64_array = base64_host_file.chars.to_a
      bytes_copied = 0
      base64_array.each_slice(8000 - remote_path.size) do |chunk|
        cmd("echo #{chunk.join} >> \"#{remote_path}\"")
        bytes_copied += chunk.count
        yield bytes_copied, base64_array.count, local_path, remote_path if block_given?
      end
      base64_array.length
    end

    def decode_command
      <<-EOH
        $base64_string = Get-Content '#{remote_path}'
        $bytes = [System.Convert]::FromBase64String($base64_string)
        [System.IO.File]::WriteAllBytes('#{remote_path}', $bytes) | Out-Null
      EOH
    end

    def create_post_upload_command
      [decode_command]
    end

    def powershell_batch(&block)
      ps_builder = []
      yield ps_builder

      commands = [ "$result = @{}" ]
      idx = 0
      ps_builder.flatten.each do |cmd_item|
        commands << <<-EOH
          $result.ret#{idx} = Invoke-Command { #{cmd_item} }
        EOH
        idx += 1
      end
      commands << "$(ConvertTo-Json $result)"

      result = []
      JSON.parse(powershell(commands.join("\n"))).each do |k,v|
        result << v unless v.nil?
      end
      result unless result.empty?
    end

    def powershell(script)
      script = "$ProgressPreference='SilentlyContinue';" + script
      logger.debug("executing powershell script: \n#{script}")
      script = script.encode('UTF-16LE', 'UTF-8')
      script = Base64.strict_encode64(script)
      cmd("powershell", ['-encodedCommand', script])
    end

    def cmd(command, arguments = [])
      command_output = nil
      out_stream = []
      err_stream = []
      service.run_command(shell, command, arguments) do |command_id|
        command_output = service.get_command_output(shell, command_id) do |stdout, stderr|
          out_stream << stdout if stdout
          err_stream << stderr if stderr
        end
      end

      if !command_output[:exitcode].zero? or !err_stream.empty?
        raise WinRMUploadError,
          :from => local_path,
          :to => remote_path,
          :message => command_output.inspect
      end
      out_stream.join.chomp
    end
  end
end