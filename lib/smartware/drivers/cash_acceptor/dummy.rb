# coding: utf-8
module Smartware
  module Driver
    module CashAcceptor

      class Dummy
        attr_reader   :bill_types

        attr_accessor :open, :closed, :escrow, :stacked, :returned, :status
        attr_accessor :enabled_types

        def initialize(config)
          @bill_types = [ 10, 50, 100, 500, 5000 ].map do |value|
            Interface::CashAcceptor::BillType.new(value, 'RUS')
          end

          @open = nil
          @closed = nil
          @escrow = nil
          @stacked = nil
          @returned = nil
          @status = nil
          @escrow_bill = nil
          @casette = true

          @enabled_types = 0

          EventMachine.add_periodic_timer 0.5, method(:poll)

          @dummy_state = :power_up
        end

        def model
          "Generic cash acceptor"
        end

        def version
          "1.0"
        end

        def accepting?
          false
        end

        def insert_casette
          @casette = true
        end

        def eject_casette
          @casette = false
        end

        private

        def poll
          error = nil

          case @dummy_state
          when :power_up
            @dummy_state = :initialize

          when :initialize
            @dummy_state = :disabled

          when :disabled
            if !@casette
              @dummy_state = :no_casette
            elsif @enabled_types != 0
              @dummy_state = :idle
              @open.call
            end

          when :idle
            if @enabled_types == 0
              @dummy_state = :disabled
              @closed.call
            elsif !@casette
              @dummy_state = :no_casette
            else
              bill, index = @bill_types.each_with_index
                                       .select { |(obj, index)| enabled_types & (1 << index) != 0 }
                                       .sample


              @dummy_state = :escrow
              @escrow_bill = bill
            end

          when :escrow
            if @escrow.call(@escrow_bill)
              @dummy_state = :stacking
            else
              @dummy_state = :returning
            end

          when :stacking
            @dummy_state = :idle
            @stacked.call @escrow_bill

          when :returning
            @dummy_state = :idle
            @return.call @escrow_bill

          when :no_casette
            error = Interface::CashAcceptor::DROP_CASETTE_OUT_OF_POSITION

            if @casette
              @dummy_state = :disabled
            end
          end

          @status.call error
        end
      end
    end
  end
end
