require_relative 'command_executor'

module WinRM
  class Base64FileDecoder

    def initialize(command_executor)
      @command_executor = command_executor
    end

    def decode(base64_encoded_file, dest_file)
      script = decode_script(base64_encoded_file, dest_file)
      @command_executor.run_powershell(script)
    end

    private

    def decode_script(base64_encoded_file, dest_file)
      <<-EOH
        $tempFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath('#{base64_encoded_file}')
        $destFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath('#{dest_file}')

        # ensure the file's containing directory exists
        $destDir = ([System.IO.Path]::GetDirectoryName($destFile))
        if (!(Test-Path $destDir)) {
          New-Item -ItemType directory -Force -Path $destDir | Out-Null
        }

        # get the encoded temp file contents, decode, and write to final dest file
        $base64Content = Get-Content $tempFile
        if ($base64Content -eq $null) {
          New-Item -ItemType file -Force $destFile
        } else {
          $bytes = [System.Convert]::FromBase64String($base64Content)
          [System.IO.File]::WriteAllBytes($destFile, $bytes) | Out-Null
        }
      EOH
    end
  end
end