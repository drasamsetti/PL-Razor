dir = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift File.expand_path(File.join(dir, '..', 'lib'))

require 'project_occam'
require 'rspec'
require 'json'
require 'net/http'
