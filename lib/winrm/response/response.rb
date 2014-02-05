module WinRM
  class Response

    attr_reader :exit_code
    attr_reader :output

    def initialize(exit_code, output)
      @exit_code = exit_code
      @output = parse_output(output)
    end

    def success?
      exit_code == 0
    end

    def error?
      !success?
    end

    def to_s
      output
    end

    private

      # Takes the output from WinRM::Request::ReadOutputStreams#read_streams
      # and parses it into a String
      # 
      # @example read_streams returns an Array of Hashes. Each Hash either has an
      #   stdout or stderr key and the corresponding String output as a value.
      # 
      #   [{:stderr=>"'foo' is not recognized as an internal or external command,\r\noperable program or batch file.\r\n"}]
      #
      # @param  output [Array]
      # 
      # @return [String]
      def parse_output(output)
        output.collect(&:values).join unless output.nil?
      end
  end
end