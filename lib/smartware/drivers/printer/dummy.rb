# coding: utf-8
module Smartware
  module Driver
    module Printer

      class Dummy

        def initialize(config)

        end

        def error
          false
        end

        def model
          'Generic printer'
        end

        def version
          'from hell'
        end
      end

    end
  end
end

