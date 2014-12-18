require 'io/console'
require 'json'
require_relative 'command_executor'
require_relative 'base64_temp_file_decoder'

module WinRM
  class RemoteFile

    attr_reader :local_path
    attr_reader :remote_path
    attr_reader :temp_path
    attr_reader :shell

    def initialize(command_executor, local_path, remote_path)
      @logger = Logging.logger[self]
      @local_path = local_path
      @remote_path = remote_path
      @command_executor = command_executor
    end

    def upload(&block)
      @logger.debug("Uploading file: #{@local_path} -> #{@remote_path}")
      raise WinRMUploadError.new("Cannot find path: #{@local_path}") unless File.exist?(@local_path)

      @temp_path = @command_executor.run_powershell(resolve_tempfile_command).chomp

      if !@temp_path.to_s.empty?
        size = upload_to_tempfile(&block)
        decoder = WinRM::Base64TempFileDecoder.new(@command_executor)
        decoder.decode(@temp_path, @remote_path)
      else
        size = 0
        @logger.debug("Files are equal. Not copying #{@local_path} to #{@remote_path}")
      end

      return size
    rescue WinRMUploadError => e
      # add additional context, from and to
      raise WinRMUploadError,
        :from => @local_path,
        :to => @remote_path,
        :message => e.message
    end
    
    protected

    def upload_to_tempfile(&block)
      @logger.debug("Uploading to temp file #{@temp_path}")
      base64_host_file = Base64.encode64(IO.binread(@local_path)).gsub("\n", "")
      base64_array = base64_host_file.chars.to_a
      bytes_copied = 0
      if base64_array.empty?
        @command_executor.run_powershell(create_empty_destfile_command)
      else
        base64_array.each_slice(8000 - @temp_path.size) do |chunk|
          @command_executor.run_cmd("echo #{chunk.join} >> \"#{@temp_path}\"")
          bytes_copied += chunk.count
          yield bytes_copied, base64_array.count, @local_path, @remote_path if block_given?
        end
      end
      base64_array.length
    end

    def resolve_tempfile_command()
      local_md5 = Digest::MD5.file(@local_path).hexdigest
      <<-EOH
        # get the resolved target path
        $destFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("#{@remote_path}")

        # check if file is up to date
        if (Test-Path $destFile) {
          $cryptoProv = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider

          $file = [System.IO.File]::Open($destFile,
            [System.IO.Filemode]::Open, [System.IO.FileAccess]::Read)
          $guestMd5 = ([System.BitConverter]::ToString($cryptoProv.ComputeHash($file)))
          $guestMd5 = $guestMd5.Replace("-","").ToLower()
          $file.Close()

          # file content is up to date, send back an empty file path to signal this
          if ($guestMd5 -eq '#{local_md5}') {
            return ''
          }
        }

        # file doesn't exist or out of date, return a unique temp file path to upload to
        return [System.IO.Path]::GetTempFileName()
      EOH
    end

    def create_empty_destfile_command()
      <<-EOH
        $destFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath('#{@remote_path}')
        New-Item $destFile -type file
      EOH
    end

  end
end
