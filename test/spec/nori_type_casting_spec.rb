$: << File.dirname(__FILE__)
require 'spec_helper'
require 'Nori'

describe "Test Nori Type Cast Toggler", :unit => true do
  before(:all) do
    @winrm = winrm_connection
  end

  it 'should have nori advanced type casting on' do
    expect(Nori.advanced_typecasting?).to be true
  end

  it 'should turn off nori advanced type casting' do
    @winrm.toggle_nori_type_casting :off
    expect(Nori.advanced_typecasting?).to be false
  end

  it 'should return nori advanced type casting to the original state' do
    @winrm.toggle_nori_type_casting :original
    expect(Nori.advanced_typecasting?).to be true
  end

  it 'should turn on nori advanced type casting' do
    @winrm.toggle_nori_type_casting :off
    @winrm.toggle_nori_type_casting :on
    expect(Nori.advanced_typecasting?).to be true
  end

end
