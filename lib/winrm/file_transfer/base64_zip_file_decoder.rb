require_relative 'command_executor'

module WinRM
  # Decodes a base64 file on a target machine and writes it out
  class Base64ZipFileDecoder < Base64FileDecoder

    def initialize(command_executor)
      @command_executor = command_executor
    end

    # Decodes the given base64 encoded file, unzips it, and writes it to the dest
    # @param [String] Path to the base64 encoded zip file on the target machine.
    # @param [String] Path to the unzip location on the target machine.
    def decode(base64_encoded_zip_file, dest_file)
      # Windows shell unzip requires the file ends with .zip
      unencoded_zip_file = "#{base64_encoded_zip_file}.zip"
      script =  decode_script(base64_encoded_zip_file, unencoded_zip_file)
      script += "\n" + unzip_script(unencoded_zip_file, dest_file)

      @command_executor.run_powershell(script)
    end

    private

    def unzip_script(zip_file, dest_file)
      <<-EOH
        $zip = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("#{zip_file}")
        $zipFile = [System.IO.Path]::GetFullPath($zip)
        $dest = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("#{dest_file}")
        $destDir = [System.IO.Path]::GetFullPath($dest)

        mkdir $destDir -ErrorAction SilentlyContinue | Out-Null
        
        $shellApplication = new-object -com shell.application 
        $zipPackage = $shellApplication.NameSpace($zipFile) 
        $destinationFolder = $shellApplication.NameSpace($destDir) 
        $destinationFolder.CopyHere($zipPackage.Items(),0x10) | Out-Null
      EOH
    end
  end
end