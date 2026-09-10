# frozen_string_literal: true

require 'stringio'
require 'winrm'
require 'winrm/compat_logger'

describe WinRM::CompatLogger do
  let(:io) { StringIO.new }
  let(:logger) { WinRM::CompatLogger.new(io) }

  it 'is a stdlib Logger' do
    expect(logger).to be_a(::Logger)
  end

  it 'logs through the standard API' do
    logger.level = :debug
    logger.info('hello')
    expect(io.string).to include('hello')
  end

  it 'accepts add_appenders with a deprecation warning instead of raising' do
    expect { logger.add_appenders(:stdout) }.not_to raise_error
    expect { WinRM::CompatLogger.new(io).add_appenders(:stdout) }
      .to output(/DEPRECATION.*add_appenders/).to_stderr
  end

  it 'warns only once per instance' do
    expect { logger.add_appenders(:stdout) }.to output(/DEPRECATION/).to_stderr
    expect { logger.add_appenders(:stdout) }.not_to output.to_stderr
  end
end
