# coding: utf-8
module Smartware
  module Driver
    module CashAcceptor

      class Dummy

        def initialize(port)
          @port = port
        end

        def model
          "Generic cash acceptor"
        end

        def version
          # TODO: implement this
          "not implemented"
        end

        def cassette?
          true
        end

        def error
          false
        end

        def current_banknote
          return false if ( rand(9) < 6 )
          [20, 40, 60, 80].sample
        end

        def accept

        end

        def cancel_accept

        end

        def stack

        end

        def return

        end

        def reset

        end
      end

    end
  end
end
