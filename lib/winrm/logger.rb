module WinRM
  module Logger
    def info(message)
      WinRM.logger.info(message)
    end

    def warn(message)
      WinRM.logger.warn(message)
    end

    def error(message)
      WinRM.logger.error(message)
    end

    def debug(message)
      WinRM.logger.debug(message)
    end
  end
end