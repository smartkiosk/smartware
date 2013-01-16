require 'thread'
require 'yaml'
require 'active_support/core_ext/string/inflections'
require 'drb'
require 'redcarpet'

require 'smartkiosk/common'

require 'smartware/version'
require 'smartware/logging'
require 'smartware/service'
require 'smartware/process_manager'
require 'smartware/clients/cash_acceptor'
require 'smartware/clients/printer'
require 'smartware/clients/modem'
require 'smartware/interfaces/interface'
require 'smartware/interfaces/cash_acceptor'
require 'smartware/interfaces/modem'
require 'smartware/interfaces/printer'

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

end