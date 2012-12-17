# coding: utf-8
module Smartware
  module Driver
    module Printer

      class Dummy

        def initialize(port)

        end

        def error
          false
        end

        def model
          'Dummy printer'
        end

      end

    end
  end
end

