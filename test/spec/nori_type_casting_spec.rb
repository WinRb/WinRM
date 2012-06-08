$: << File.dirname(__FILE__)
require 'spec_helper'
require 'Nori'

describe "Test Nori Type Cast Toggler" do
  before(:all) do
    @winrm = winrm_connection
  end

  it 'should have nori advanced type casting on' do
    Nori.advanced_typecasting?.should == true
  end

  it 'should turn off nori advanced type casting' do
    @winrm.toggle_nori_type_casting :off
    Nori.advanced_typecasting?.should == false
  end

  it 'should return nori advanced type casting to the original state' do
    @winrm.toggle_nori_type_casting :original
    Nori.advanced_typecasting?.should == true
  end

  it 'should turn on nori advanced type casting' do
    @winrm.toggle_nori_type_casting :off
    @winrm.toggle_nori_type_casting :on
    Nori.advanced_typecasting?.should == true
  end

end
