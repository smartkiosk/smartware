require 'smartkiosk/common'
require 'smartware/logging'
require 'smartware/service'
require 'smartware/clients/cash_acceptor'
require 'smartware/clients/printer'
require 'smartware/clients/modem'

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