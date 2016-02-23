# encoding: UTF-8
describe 'WinRM connection' do
  let(:winrm_connection) do
    endpoint = config[:endpoint].dup
    if auth_type == :ssl
      endpoint.sub!('5985', '5986')
      endpoint.sub!('http', 'https')
    end
    winrm = WinRM::WinRMWebService.new(
      endpoint, auth_type, options)
    winrm.logger.level = :error
    winrm
  end
  let(:options) do
    opts = {}
    opts[:user] = config[:options][:user]
    opts[:pass] = config[:options][:pass]
    opts[:basic_auth_only] = basic_auth_only
    opts[:no_ssl_peer_verification] = no_ssl_peer_verification
    opts[:ssl_peer_fingerprint] = ssl_peer_fingerprint
    opts
  end
  let(:basic_auth_only) { false }
  let(:no_ssl_peer_verification) { false }
  let(:ssl_peer_fingerprint) { nil }

  subject(:output) do
    executor = winrm_connection.create_executor
    executor.run_cmd('ipconfig')
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
