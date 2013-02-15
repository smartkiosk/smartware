require 'thread'
require 'yaml'
require 'active_support/core_ext/string/inflections'
require 'drb'
require 'redcarpet'
require 'stringio'
require 'eventmachine'
require 'serialport'
require 'json'
require 'set'

require 'smartkiosk/common'

require 'smartware/version'
require 'smartware/logging'
require 'smartware/service'
require 'smartware/process_manager'
require 'smartware/client'
require 'smartware/interfaces/interface'
require 'smartware/interfaces/cash_acceptor'
require 'smartware/interfaces/modem'
require 'smartware/interfaces/printer'
require 'smartware/interfaces/watchdog'
require 'smartware/interfaces/card_reader'
require 'smartware/interfaces/pin_pad'
require 'smartware/interfaces/user_interface'
require 'smartware/connection_monitor'
require 'smartware/pub_sub_server'
require 'smartware/pub_sub_client'

module Smartware

  def self.devices
    yield self
  end

  def self.cash_acceptor
    Smartware::Client.instance('druby://localhost:6001')
  end

  def self.modem
    Smartware::Client.instance('druby://localhost:6002')
  end

  def self.watchdog
    Smartware::Client.instance('druby://localhost:6003')
  end

  def self.card_reader
    Smartware::Client.instance('druby://localhost:6004')
  end

  def self.printer
    Smartware::Client.instance('druby://localhost:6005')
  end

  def self.pin_pad
    Smartware::Client.instance('druby://localhost:6006')
  end

  def self.user_interface
      Smartware::Client.instance('druby://localhost:6007')
  end

  def self.subscribe(&block)
    Smartware::PubSubClient.destroy_static_client
    client = Smartware::PubSubClient.create_static_client
    client.receiver = block
    client.start
    client
  end

  def self.unsubscribe
    Smartware::PubSubClient.destroy_static_client
  end
end