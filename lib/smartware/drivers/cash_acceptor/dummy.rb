# coding: utf-8
module Smartware
  module Driver
    module CashAcceptor

      class Dummy
        attr_reader   :bill_types

        attr_accessor :escrow, :stacked, :returned, :status
        attr_accessor :enabled_types

        def initialize(config)
          @bill_types = []

          @escrow = nil
          @stacked = nil
          @returned = nil
          @status = nil

          @enabled_types = nil
        end

        def model
          "Generic cash acceptor"
        end

        def version
          "1.0"
        end
      end

    end
  end
end
