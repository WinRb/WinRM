module WinRM
  # This class holds raw output as a hash, and has convenience methods to parse.
  class Output < Hash
    def initialize
      super
      self[:data] = []
    end

    def output
      self[:data].flat_map do | line |
        [line[:stdout], line[:stderr]]
      end.compact.join
    end

    def stdout
      self[:data].map do | line |
        line[:stdout]
      end.compact.join
    end

    def stderr
      self[:data].map do | line |
        line[:stderr]
      end.compact.join
    end
  end
end
