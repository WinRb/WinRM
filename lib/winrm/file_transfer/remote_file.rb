require_relative 'base64_file_decoder'
require_relative 'base64_zip_file_decoder'
require_relative 'base64_file_uploader'
require_relative 'md5_temp_file_resolver'
require_relative 'command_executor'

module WinRM
  class RemoteFile

    def self.single_remote_file(service)
      create_remote_file(service) do |cmd_executor|
        WinRM::Base64FileDecoder.new(cmd_executor)
      end
    end

    def self.multi_remote_file(service)
      create_remote_file(service) do |cmd_executor|
        WinRM::Base64ZipFileDecoder.new(cmd_executor)
      end
    end

    def initialize(cmd_executor, temp_file_resolver, file_uploader, file_decoder)
      @logger = Logging.logger[self]
      @cmd_executor = cmd_executor
      @temp_file_resolver = temp_file_resolver
      @file_uploader = file_uploader
      @file_decoder = file_decoder
    end

    def upload(local_path, remote_path, &block)
      @cmd_executor.open()

      temp_path = @temp_file_resolver.temp_file_path(local_path, remote_path)
      if temp_path.empty?
        @logger.debug("Content up to date, skipping: #{local_path}")
        return 0
      end

      @logger.debug("Uploading: #{local_path} -> #{remote_path}")
      size = @file_uploader.upload_to_temp_file(local_path, temp_path, remote_path, &block)
      @file_decoder.decode(temp_path, remote_path)

      size
    rescue WinRMUploadError => e
      # add additional context, from and to
      raise WinRMUploadError,
        :from => local_path,
        :to => remote_path,
        :message => e.message
    ensure
      @cmd_executor.close()
    end

    private

    def self.create_remote_file(service, &block)
      cmd_executor = WinRM::CommandExecutor.new(service)
      temp_file_resolver = WinRM::Md5TempFileResolver.new(cmd_executor)
      file_uploader = WinRM::Base64FileUploader.new(cmd_executor)
      file_decoder = block.call(cmd_executor)
      WinRM::RemoteFile.new(cmd_executor, temp_file_resolver, file_uploader, file_decoder)
    end
  end
end