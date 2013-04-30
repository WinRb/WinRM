require 'simplecov'
SimpleCov.start do
  add_filter "/spec/"
end
$: << File.dirname(__FILE__) + '/../../lib/'
require 'winrm'
require 'unit/shared_examples'