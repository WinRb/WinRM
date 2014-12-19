module WinRM
  class RemoteFile

    def initialize(temp_file_resolver, file_uploader, file_decoder)
      @logger = Logging.logger[self]
      @temp_file_resolver = temp_file_resolver
      @file_uploader = file_uploader
      @file_decoder = file_decoder
    end

    def upload(local_path, remote_path, &block)
      temp_path = @temp_file_resolver.temp_file_path(local_path, remote_path)
      if temp_path.empty?
        @logger.debug("Content up to date, skipping: #{local_path}")
        return 0
      end

      size = @file_uploader.upload_to_temp_file(local_path, temp_path, remote_path, &block)
      @file_decoder.decode(temp_path, remote_path)

      size
    rescue WinRMUploadError => e
      # add additional context, from and to
      raise WinRMUploadError,
        :from => local_path,
        :to => remote_path,
        :message => e.message
    end
  end
end