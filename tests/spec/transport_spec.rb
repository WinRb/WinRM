# encoding: UTF-8
require 'rubyntlm'
require 'winrm/http/transport'

describe WinRM::HTTP::HttpNegotiate do
  describe '#init' do
    let(:endpoint) { 'some_endpoint' }
    let(:domain) { 'some_domain' }
    let(:user) { 'some_user' }
    let(:password) { 'some_password' }
    let(:options) { {} }

    context 'user is not domain prefixed' do
      it 'does not pass a domain to the NTLM client' do
        expect(Net::NTLM::Client).to receive(:new).with(user, password, options)
        WinRM::HTTP::HttpNegotiate.new(endpoint, user, password, options)
      end
    end

    context 'user is domain prefixed' do
      it 'passes prefixed domain to the NTLM client' do
        expect(Net::NTLM::Client).to receive(:new) do |passed_user, passed_password, passed_options|
          expect(passed_user).to eq user
          expect(passed_password).to eq password
          expect(passed_options[:domain]).to eq domain
        end
        WinRM::HTTP::HttpNegotiate.new(endpoint, "#{domain}\\#{user}", password, options)
      end
    end

    context 'option is passed with a domain' do
      let(:options) { { domain: domain } }

      it 'passes domain option to the NTLM client' do
        expect(Net::NTLM::Client).to receive(:new) do |passed_user, passed_password, passed_options|
          expect(passed_user).to eq user
          expect(passed_password).to eq password
          expect(passed_options[:domain]).to eq domain
        end
        WinRM::HTTP::HttpNegotiate.new(endpoint, user, password, options)
      end
    end
  end
end
