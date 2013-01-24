module Smartware
  module Driver
    module Printer

      class Dummy

        def initialize(config)

        end

        def status
          :ready
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
          name = "smartwareprint_#{Time.now.strftime("%Y-%m-%d-%H:%M:%S")}.txt"
          pathname = File.join(Dir.home, name)

          File.open(pathname, 'w') { |io| io.write data }

          Logging.logger.info "Created #{pathname}"

          true
        end

        def query

        end

        def new_render
          DummyRender.new
        end
      end

      class DummyRender < Redcarpet::Render::Base
        def linebreak
          "\n"
        end

        def normal_text(text, keep_newlines = false)
          unless keep_newlines
            text.gsub! "\n", " "
          end

          text
        end
      end
    end
  end
end

