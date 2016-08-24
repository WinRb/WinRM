# encoding: UTF-8
require 'winrm/exceptions'
require 'winrm/http/transport_factory'

module WinRM
  module HTTP
    # Remove the gssapi stuff in kerberos init for tests
    class HttpGSSAPI < HttpTransport
      def initialize(endpoint, realm, opts, service = nil)
      end
    end
  end
end

describe WinRM::HTTP::TransportFactory do
  describe '#create_transport' do
    let(:transport) { :negotiate }
    let(:options) do
      {
        transport: transport,
        endpoint: 'endpoint',
        user: 'user'
      }
    end

    it 'creates a negotiate transport' do
      options[:transport] = :negotiate
      expect(subject.create_transport(options)).to be_a(WinRM::HTTP::HttpNegotiate)
    end

    it 'creates a plaintext transport' do
      options[:transport] = :plaintext
      expect(subject.create_transport(options)).to be_a(WinRM::HTTP::HttpPlaintext)
    end

    it 'creates a basic auth ssl transport' do
      options[:transport] = :ssl
      options[:basic_auth_only] = true
      expect(subject.create_transport(options)).to be_a(WinRM::HTTP::BasicAuthSSL)
    end

    it 'creates a client cert ssl transport' do
      options[:transport] = :ssl
      options[:client_cert] = 'cert'
      expect(subject.create_transport(options)).to be_a(WinRM::HTTP::ClientCertAuthSSL)
    end

    it 'creates a negotiate over ssl transport' do
      options[:transport] = :ssl
      expect(subject.create_transport(options)).to be_a(WinRM::HTTP::HttpNegotiate)
    end

    it 'creates a kerberos transport' do
      options[:transport] = :kerberos
      expect(subject.create_transport(options)).to be_a(WinRM::HTTP::HttpGSSAPI)
    end

    it 'creates a transport from a stringified transport' do
      options[:transport] = 'negotiate'
      expect(subject.create_transport(options)).to be_a(WinRM::HTTP::HttpNegotiate)
    end

    it 'raises when transport type does not exist' do
      options[:transport] = :fancy
      expect { subject.create_transport(options) }.to raise_error(WinRM::InvalidTransportError)
    end
  end
end
