module Smartware
  module Interface
    class CardReader < Interface
      COMMUNICATION_ERROR = 1
      HARDWARE_ERROR      = 2
      CARD_JAM_ERROR      = 3
      CARD_ERROR          = 4
      MAG_READ_ERROR      = 5
      ICC_ERROR           = 6

      class CardReaderError < RuntimeError
        attr_reader :code

        def initialize(message, code)
          super(message)

          @code = code
        end
      end

      def initialize(config)
        super

        @status[:model] = @device.model
        @status[:version] = @device.version
      end

      def card_inserted?
        @device.status == :card_inserted
      rescue CardReaderError => e
        @status[:error] = e.code
        nil
      end

      def start_accepting
        @device.accepting = true
        @status[:error] = nil
        true
      rescue CardReaderError => e
        @status[:error] = e.code
        false
      end

      def stop_accepting
        @device.accepting = false
        @status[:error] = nil
        true
      rescue CardReaderError => e
        @status[:error] = e.code
        false
      end

      def eject
        @device.eject

        sleep 0.5 while @device.status == :card_at_gate

        @status[:error] = nil
        true
      rescue CardReaderError => e
        @status[:error] = e.code
        false
      end

      def capture
        @device.capture
        @status[:error] = nil
        true
      rescue CardReaderError => e
        @status[:error] = e.code
        false
      end

      def read_magstrip
        data = {}
        iso1, iso2, iso3, jis2 = @device.read_magstrip

        raise CardReaderError.new("ISO Track #1 is not present", MAG_READ_ERROR) if iso1.nil?

        io = StringIO.new(iso1, "r")

        encoding = io.readchar
        if encoding != 'B'
          raise CardReaderError.new("Invalid track #1 encoding: #{encoding}", MAG_READ_ERROR)
        end

        data[:pan] = io.readline("^")[0...-1]
        data[:name] = io.readline("^")[0...-1]

        expiration = io.readchar
        if expiration == '^'
          data[:expiration] = nil
        else
          expiration << io.read(3)
          raise CardReaderError.new("Expiration is malformed", MAG_READ_ERROR) if expiration.length != 4
          data[:expiration] = expiration
        end

        service_code = io.readchar
        if service_code == '^'
          data[:service_code] = nil
        else
          service_code << io.read(2)
          raise CardReaderError.new("Service code is malformed", MAG_READ_ERROR) if service_code.length != 3
          data[:service_code] = decode_service_code(service_code)
        end

        data[:discretionary_data] = io.read

        @status[:error] = nil
        data

      rescue EOFError
        @status[:error] = MAG_READ_ERROR
        nil
      rescue CardReaderError => e
        @status[:error] = e.code
        nil
      end

      private

      def decode_service_code(code)
        interchange, techonology, authorization, allowed_services, pin_requirements = nil

        case code[0]
        when '1'
          interchange = :international

        when '2'
          interchange = :international
          techonology = :icc

        when '5'
          interchange = :national

        when '6'
          interchange = :national
          techonology = :icc

        when '7'
          interchange = :private

        when '9'
          interchange = :test

        else
          raise CardReaderError("invalid service code: #{code}", MAG_READ_ERROR)
        end

        case code[1]
        when '0'
          authorization = :normal

        when '2'
          authorization = :by_issuer

        when '4'
          authorization = :by_issuer_unless_agreed

        else
          raise CardReaderError("invalid service code: #{code}", MAG_READ_ERROR)
        end

        case code[2]
        when '0'
          allowed_services = :unrestricted
          pin_requirements = :required

        when '1'
          allowed_services = :unrestricted

        when '2'
          allowed_services = :goods_and_services

        when '3'
          allowed_services = :atm
          pin_requirements = :required

        when '4'
          allowed_services = :cash

        when '5'
          allowed_services = :goods_and_services
          pin_requirements = :required

        when '6'
          allowed_services = :unrestricted
          pin_requirements = :if_possible

        when '7'
          allowed_services = :goods_and_services
          pin_requirements = :if_possible

        else
          raise CardReaderError("invalid service code: #{code}", MAG_READ_ERROR)
        end

        {
          interchange: interchange,
          techonology: techonology,
          authorization: authorization,
          allowed_services: allowed_services,
          pin_requirements: pin_requirements
        }
      end
    end
  end
end
