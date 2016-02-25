# encoding: UTF-8
require 'winrm/connection_opts'

describe WinRM::ConnectionOpts do
  context 'when there are no overrides' do
    describe '#create_with_defaults' do
      it 'throws a validation error' do
        expect { WinRM::ConnectionOpts.create_with_defaults({}) }.to raise_error
      end
    end
  end
  context 'when username, password, and endpoint are given' do
    let(:overrides) do
      {
        user: 'Administrator',
        password: 'password',
        endpoint: 'http://localhost:5985/wsman'
      }
    end
    describe '#create_with_defaults' do
      it 'creates a ConnectionOpts object' do
        config = WinRM::ConnectionOpts.create_with_defaults(overrides)
        expect(config[:user]).to eq(overrides[:user])
        expect(config[:password]).to eq(overrides[:password])
        expect(config[:endpoint]).to eq(overrides[:endpoint])
      end
    end
  end
  context 'when overrides are provided' do
    let(:overrides) do
      {
        user: 'Administrator',
        password: 'password',
        endpoint: 'http://localhost:5985/wsman',
        transport: :ssl
      }
    end
    describe '#create_with_defaults' do
      it 'creates a ConnectionOpts object with overrides' do
        config = WinRM::ConnectionOpts.create_with_defaults(overrides)
        expect(config[:transport]).to eq(overrides[:transport])
      end
    end
  end
  context 'when receive_timeout is specified' do
    let(:overrides) do
      {
        user: 'Administrator',
        password: 'password',
        endpoint: 'http://localhost:5985/wsman',
        receive_timeout: 120
      }
    end
    describe '#create_with_defaults' do
      it 'creates a ConnectionOpts object with the correct receive_timeout' do
        config = WinRM::ConnectionOpts.create_with_defaults(overrides)
        expect(config[:receive_timeout]).to eq(overrides[:receive_timeout])
      end
    end
  end
  context 'when operation_timeout is specified' do
    let(:overrides) do
      {
        user: 'Administrator',
        password: 'password',
        endpoint: 'http://localhost:5985/wsman',
        operation_timeout: 120
      }
    end
    describe '#create_with_defaults' do
      it 'creates a ConnectionOpts object with the correct timeouts' do
        config = WinRM::ConnectionOpts.create_with_defaults(overrides)
        expect(config[:operation_timeout]).to eq(overrides[:operation_timeout])
        expect(config[:receive_timeout]).to eq(overrides[:operation_timeout] + 10)
      end
    end
  end
  context 'when invalid data types are given' do
    let(:overrides) do
      {
        user: 'Administrator',
        password: 'password',
        endpoint: 'http://localhost:5985/wsman',
        operation_timeout: 'PT60S'
      }
    end
    describe '#create_with_defaults' do
      it 'raises an error' do
        expect { WinRM::ConnectionOpts.create_with_defaults(overrides) }.to raise_error
      end
    end
  end
end
