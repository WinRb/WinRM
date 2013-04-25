require 'simplecov'
SimpleCov.start
$: << File.dirname(__FILE__) + '/../../lib/'
require 'winrm'
require 'unit/shared_examples'