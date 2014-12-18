require 'io/console'
require 'json'
require_relative 'command_executor'
require_relative 'base64_temp_file_decoder'
require_relative 'md5_temp_file_resolver'

module WinRM
  class RemoteFile

    attr_reader :local_path
    attr_reader :remote_path
    attr_reader :temp_path

    def initialize(command_executor, local_path, remote_path)
      @logger = Logging.logger[self]
      @local_path = local_path
      @remote_path = remote_path
      @command_executor = command_executor
    end

    def upload(&block)
      @logger.debug("Uploading file: #{@local_path} -> #{@remote_path}")
      raise WinRMUploadError.new("Cannot find path: #{@local_path}") unless File.exist?(@local_path)

      temp_file_resolver = WinRM::Md5TempFileResolver.new(@command_executor)
      @temp_path = temp_file_resolver.temp_file_path(@local_path, @remote_path)

      if @temp_path.empty?
        @logger.debug("Files are equal. Not copying #{@local_path} to #{@remote_path}")
        return 0
      end

      size = upload_to_tempfile(&block)
      decoder = WinRM::Base64TempFileDecoder.new(@command_executor)
      decoder.decode(@temp_path, @remote_path)
      size
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

    def create_empty_destfile_command()
      <<-EOH
        $destFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath('#{@remote_path}')
        New-Item $destFile -type file
      EOH
    end

  end
end
