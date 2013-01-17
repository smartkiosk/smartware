require 'thread'
require 'yaml'
require 'active_support/core_ext/string/inflections'
require 'drb'
require 'redcarpet'
require 'stringio'

require 'smartkiosk/common'

require 'smartware/version'
require 'smartware/logging'
require 'smartware/service'
require 'smartware/process_manager'
require 'smartware/clients/cash_acceptor'
require 'smartware/clients/printer'
require 'smartware/clients/modem'
require 'smartware/clients/watchdog'
require 'smartware/clients/card_reader'
require 'smartware/interfaces/interface'
require 'smartware/interfaces/cash_acceptor'
require 'smartware/interfaces/modem'
require 'smartware/interfaces/printer'
require 'smartware/interfaces/watchdog'
require 'smartware/interfaces/card_reader'
require 'smartware/connection_monitor'

module Smartware

  def self.devices
    yield self
  end

  def self.cash_acceptor
    Smartware::Client::CashAcceptor
  end

  def self.printer
    Smartware::Client::Printer
  end

  def self.modem
    Smartware::Client::Modem
  end

  def self.watchdog
    Smartware::Client::Watchdog
  end

end