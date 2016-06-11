# encoding: UTF-8
require_relative 'spec_helper'

describe 'WinRM connection' do
  let(:connection) do
    endpoint = connection_opts[:endpoint].dup
    if auth_type == :ssl
      endpoint.sub!('5985', '5986')
      endpoint.sub!('http', 'https')
    end
    conn_options = {
      transport: auth_type,
      endpoint: endpoint
    }.merge(options)
    WinRM::Connection.new(conn_options).shell(:cmd)
  end
  let(:options) do
    opts = {}
    opts[:user] = connection_opts[:user]
    opts[:password] = connection_opts[:password]
    opts[:basic_auth_only] = basic_auth_only
    opts[:no_ssl_peer_verification] = no_ssl_peer_verification
    opts[:ssl_peer_fingerprint] = ssl_peer_fingerprint
    opts[:client_cert] = user_cert
    opts[:client_key] = user_key
    opts
  end
  let(:basic_auth_only) { false }
  let(:no_ssl_peer_verification) { false }
  let(:ssl_peer_fingerprint) { nil }
  let(:user_cert) { nil }
  let(:user_key) { nil }

  subject(:output) { connection.run('ipconfig') }

  after(:each) do
    connection.close
  end

  shared_examples 'a valid_connection' do
    it 'has a 0 exit code' do
      expect(subject).to have_exit_code 0
    end

    it 'includes command output' do
      expect(subject).to have_stdout_match(/Windows IP Configuration/)
    end

    it 'has no errors' do
      expect(subject).to have_no_stderr
    end
  end

  context 'HttpPlaintext' do
    let(:basic_auth_only) { true }
    let(:auth_type) { :plaintext }

    it_behaves_like 'a valid_connection'
  end

  context 'HttpNegotiate' do
    let(:auth_type) { :negotiate }

    it_behaves_like 'a valid_connection'
  end

  context 'BasicAuthSSL', skip: ENV['winrm_cert'].nil? do
    let(:basic_auth_only) { true }
    let(:auth_type) { :ssl }
    let(:no_ssl_peer_verification) { true }

    it_behaves_like 'a valid_connection'
  end

  context 'ClientCertAuthSSL', skip: ENV['user_cert'].nil? do
    let(:auth_type) { :ssl }
    let(:no_ssl_peer_verification) { true }
    let(:user_cert) { ENV['user_cert'] }
    let(:user_key) { ENV['user_key'] }

    before { options[:pass] = nil }

    it_behaves_like 'a valid_connection'
  end

  context 'Negotiate over SSL', skip: ENV['winrm_cert'].nil? do
    let(:auth_type) { :ssl }
    let(:no_ssl_peer_verification) { true }

    it_behaves_like 'a valid_connection'
  end

  context 'SSL fingerprint', skip: ENV['winrm_cert'].nil? do
    let(:auth_type) { :ssl }
    let(:ssl_peer_fingerprint) { ENV['winrm_cert'] }

    it_behaves_like 'a valid_connection'
  end
end
