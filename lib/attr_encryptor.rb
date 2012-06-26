# encoding: UTF-8

require 'yaml'
require 'attr_encryptor/config'
require 'attr_encryptor/aes'

module AttrEncryptor
  YAML_CONFIG_FILE = '../config/attr_encryptor.yaml'

  class << self
    def included(klass)
      klass.extend ClassMethods
    end

    def aes
      @aes ||= AES.new(config.key)
    end

    def env
      defined?(Rails) && Rails.respond_to?(:env) ? Rails.env : 'development'
    end

    def config
      @config ||= initialize_config
    end

    def initialize_config
      raise "#{YAML_CONFIG_FILE} should exist on production environment" if
        env == 'production' && !File.exist?(YAML_CONFIG_FILE)
      hash = YAML.load_file(YAML_CONFIG_FILE) rescue { :key => 'secret' }
      Config.new(hash)
    end
  end

  module ClassMethods
    def attr_encryptor *attrs
      attrs.each do |attr|
        define_method("#{attr}=") do |v|
          serialized = YAML::dump(v)
          self.send "#{attr}_encrypted=", [AttrEncryptor.aes.encrypt(serialized)].pack('m')
        end
        define_method(attr) do
          return nil unless self.send("#{attr}_encrypted").is_a?(String)
          YAML::load(AttrEncryptor.aes.decrypt(self.send("#{attr}_encrypted").unpack('m')[0]))
        end
      end
    end
  end
end
