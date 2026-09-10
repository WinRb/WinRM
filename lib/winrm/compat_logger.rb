# frozen_string_literal: true

require 'logger'

module WinRM
  # Backwards-compatible default for `Connection#logger`.
  #
  # WinRM used to expose a `logging`-gem logger here; it now exposes a plain
  # stdlib {Logger} instead. This subclass keeps the small `logging`-specific
  # API callers actually used (`add_appenders`) working while emitting a
  # deprecation warning, so existing code keeps running instead of breaking
  # on upgrade. Everything else is exactly stdlib `Logger` behavior.
  class CompatLogger < ::Logger
    # Accepts `logging`-gem-style appenders for backwards compatibility.
    # Stdlib loggers write to their log device, so appenders have no
    # equivalent here and are ignored.
    def add_appenders(*_appenders)
      deprecate_appenders unless @appenders_deprecated
      nil
    end

    private

    def deprecate_appenders
      @appenders_deprecated = true
      warn '[DEPRECATION] WinRM: `logger.add_appenders` is deprecated and has no effect. ' \
           'Configure the stdlib logger directly or inject your own via `Connection#logger=`.'
    end
  end
end
