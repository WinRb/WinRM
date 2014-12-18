require_relative 'command_executor'
require_relative 'base64_file_decoder'
require_relative 'base64_file_uploader'
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

      # TODO: short circuit if the source file is 0 bytes

      temp_file_resolver = WinRM::Md5TempFileResolver.new(@command_executor)
      @temp_path = temp_file_resolver.temp_file_path(@local_path, @remote_path)

      if @temp_path.empty?
        @logger.debug("Files are equal. Not copying #{@local_path} to #{@remote_path}")
        return 0
      end

      file_uploader = WinRM::Base64FileUploader.new(@command_executor)
      size = file_uploader.upload_to_temp_file(@local_path, @temp_path, @remote_path, &block)

      decoder = WinRM::Base64FileDecoder.new(@command_executor)
      decoder.decode(@temp_path, @remote_path)

      size
    rescue WinRMUploadError => e
      # add additional context, from and to
      raise WinRMUploadError,
        :from => @local_path,
        :to => @remote_path,
        :message => e.message
    end
  end
end
