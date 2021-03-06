$occam_root = File.dirname(__FILE__).sub(/\/lib$/,"")
$config_server_path = "#{$occam_root}/conf/occam_server.conf"
$img_svc_path = "#{$occam_root}/image"
$logging_path = "#{$occam_root}/log/project_occam.log"
$temp_path = "#{$occam_root}/tmp"

# In order to work correctly, we need to ensure that ENV['HOME'] has a
# sensible and correct value.  At least the Net::SSH gem will file if this is
# unset, and that can happen when Puppet fires up the daemon.
unless ENV['HOME']
  if ENV['HOMEPATH']
    ENV['HOME'] = "#{ENV['HOMEDRIVE']}#{ENV['HOMEPATH']}"
  else
    require 'etc'
    uid = Process.euid or
      raise "HOME is not set, and unable to determine current process UID"
    pwent = Etc::getpwuid(uid) or
      raise "HOME is not set, but #{uid} doesn't have an entry in the passwd db"
    pwent.dir.empty? and
      raise "HOME is not set, but #{uid} (#{pwent.name}) has an empty home directory"
    # Note, we carefully don't check that this is a valid directory or
    # anything like that.  It can point to a non-existent location just fine,
    # since that is what the login process would do. --daniel 2012-11-19
    ENV['HOME'] = pwent.dir
  end
end


require 'set'
require "project_occam/version"
require "project_occam/object"
require "project_occam/utility"
require "project_occam/logging"
require "project_occam/error"
require "project_occam/data"
require "project_occam/config"
require "project_occam/node"
require "project_occam/policy"
require "project_occam/engine"
require "project_occam/slice"
require "project_occam/persist"
require "project_occam/model"
require "project_occam/tagging"
require "project_occam/policies"
require "project_occam/image_service"
require "project_occam/power_control"
require "project_occam/broker"


# Root ProjectOccam namespace
module ProjectOccam
  # Provide access to the global configuration for the project.
  #
  # This makes the global data available fairly uniformly to the project,
  # replacing the older mechanism of connecting to the database to access the
  # configuration object by coincidence, navigating through the
  # data abstraction.
  def self.config
    ProjectOccam::Config::Server.instance
  end
end

class ::Object
  # Returns hash of classes that are children of
  # the namespace that called the method.
  # For example: ProjectOccam::Slice.class_children
  def class_children
    constants.map {|e| const_get(e) }.select {|e| e.is_a?(Module) } - [self]
  end
end

# Add full_const_get from extlib to remove dependencies
class Object
  def full_const_get(name)
    list = name.split("::")
    list.shift if list.first.blank?
    obj = self
    list.each do |x|
      # This is required because const_get tries to look for constants in the
      # ancestor chain, but we only want constants that are HERE
      obj = obj.const_defined?(x) ? obj.const_get(x) : obj.const_missing(x)
    end
    obj
  end
  ##
  # Returns true if the object is nil or empty (if applicable)
  #
  #   [].blank?         #=>  true
  #   [1].blank?        #=>  false
  #   [nil].blank?      #=>  false
  #
  # @return [TrueClass, FalseClass]
  #
  # @api public
  def blank?
    nil? || (respond_to?(:empty?) && empty?)
  end
end # class Object

class Numeric
  ##
  # Numerics are never blank
  #
  #   0.blank?          #=>  false
  #   1.blank?          #=>  false
  #   6.54321.blank?    #=>  false
  #
  # @return [FalseClass]
  #
  # @api public
  def blank?
    false
  end
end # class Numeric

class NilClass
  ##
  # Nil is always blank
  #
  #   nil.blank?        #=>  true
  #
  # @return [TrueClass]
  #
  # @api public
  def blank?
    true
  end
end # class NilClass

class TrueClass
  ##
  # True is never blank.
  #
  #   true.blank?       #=>  false
  #
  # @return [FalseClass]
  #
  # @api public
  def blank?
    false
  end
end # class TrueClass

class FalseClass
  ##
  # False is always blank.
  #
  #   false.blank?      #=>  true
  #
  # @return [TrueClass]
  #
  # @api public
  def blank?
    true
  end
end # class FalseClass

class String
  ##
  # Strips out whitespace then tests if the string is empty.
  #
  #   "".blank?         #=>  true
  #   "     ".blank?    #=>  true
  #   " hey ho ".blank? #=>  false
  #
  # @return [TrueClass, FalseClass]
  #
  # @api public
  def blank?
    strip.empty?
  end
end # class String

