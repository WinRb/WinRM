# encoding: UTF-8
require 'rubygems'
require 'bundler/setup'
require 'winrm'
require 'json'
require 'openssl'
require_relative 'matchers'

# Creates a WinRM connection for integration tests
module ConnectionHelper
  def winrm_connection
    WinRM::WinRMWebService.new(
      config[:endpoint], config[:auth_type].to_sym, config[:options])
  end

  def config
    @config ||= begin
      cfg = symbolize_keys(YAML.load(File.read(winrm_config_path)))
      cfg[:options].merge!(basic_auth_only: true) unless cfg[:auth_type].eql? :kerberos
      merge_environment!(cfg)
      cfg
    end
  end

  def merge_environment!(config)
    config[:options][:user] = ENV['winrm_user'] if ENV['winrm_user']
    config[:options][:pass] = ENV['winrm_password'] if ENV['winrm_password']
    config[:endpoint] = ENV['winrm_endpoint'] if ENV['winrm_endpoint']
  end

  def winrm_config_path
    # Copy config-example.yml to config.yml and edit for your local configuration
    path = File.expand_path("#{File.dirname(__FILE__)}/config.yml")
    unless File.exist?(path)
      # user hasn't done this, so use sane defaults for unit tests
      path = File.expand_path("#{File.dirname(__FILE__)}/config-example.yml")
    end
    path
  end

  # rubocop:disable Metrics/MethodLength
  def symbolize_keys(hash)
    hash.each_with_object({}) do |(key, value), result|
      new_key = case key
                when String then key.to_sym
                else key
                end
      new_value = case value
                  when Hash then symbolize_keys(value)
                  else value
                  end
      result[new_key] = new_value
      result
    end
  end
  # rubocop:enable Metrics/MethodLength

  # create a simple cert for a public_key
  def test_cert(public_key)
    subject = OpenSSL::X509::Name.parse('/C=BE/O=Test/OU=Test/CN=Test')
    cert = OpenSSL::X509::Certificate.new
    cert.subject = cert.issuer = subject
    cert.not_before = Time.now
    cert.not_after = Time.now + 365 * 24 * 3600
    cert.public_key = public_key
    cert.serial = 0x0
    cert.version = 2
    cert
  end

  # add CA and subject extensions to cert
  def add_cert_extensions(cert)
    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = cert
    ef.issuer_certificate = cert
    cert.extensions = [
      ef.create_extension('basicConstraints', 'CA:TRUE', true),
      ef.create_extension('subjectKeyIdentifier', 'hash'),
      # ef.create_extension('keyUsage', 'cRLSign,keyCertSign', true),
    ]
    cert.add_extension ef.create_extension('authorityKeyIdentifier',
                                           'keyid:always,issuer:always')
    cert
  end

  # create a self-signed-cert from private key
  def gen_self_signed_cert(key)
    plain_cert = test_cert(key.public_key)
    cert = add_cert_extensions(plain_cert)
    cert.sign key, OpenSSL::Digest::SHA1.new
    cert
  end
end

RSpec.configure do |config|
  config.include(ConnectionHelper)
end
