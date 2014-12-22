module WinRM
  class PowershellScript

    attr_reader :text

    # Creates a new PowershellScript object which can be used to encode
    # PS scripts for safe transport over WinRM.
    # @param [String] The PS script text content
    def initialize(script)
      @text = script
    end

    # Encodes the script so that it can be passed to the PowerShell
    # --EncodedCommand argument.
    # @return [String] The UTF-16LE base64 encoded script
    def encoded()
      encoded_script = text.encode('UTF-16LE', 'UTF-8')
      Base64.strict_encode64(encoded_script)
    end

  end
end
