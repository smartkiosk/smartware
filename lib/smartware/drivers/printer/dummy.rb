module Smartware
  module Driver
    module Printer

      class Dummy

        def initialize(config)

        end

        def error
          nil
        end

        def model
          'Generic printer'
        end

        def version
          'from hell'
        end

        def print(data)

        end

        def query

        end

        def new_render
          Redcarpet::Render::HTML.new
        end
      end

    end
  end
end

