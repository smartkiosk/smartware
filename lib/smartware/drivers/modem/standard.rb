# coding: utf-8
require 'cmux'

module Smartware
  module Driver
    module Modem

      class Standard
        attr_reader :error, :model, :balance

        def initialize(config)
          @config = config
          @state = :closed
          @error = "not initialized yet"
          @mux = nil
          @status_channel = nil
          @info_requested = false
          @model = "GSM modem"
          @signal = "+CSQ: 99,99"
          @ussd_interval = 0
          @balance = nil
          @ppp_state = :stopped
          @ppp_pid = nil
        end

        def signal_level
          value = @signal.gsub("+CSQ: ",'').split(',')[0].to_i
          "#{(-113 + value * 2)} dbm"
        end

        def tick
          begin
            modem_tick
            ppp_tick

            wait_for_event
          rescue => e
            Smartware::Logging.logger.error "uncatched exception in modem monitor: #{e}"
          end
        end

        def unsolicited(type, fields)
          case type
          when "CUSD"
            ussd *fields
          end
        end

        def ussd(mode, string = nil, dcs = nil)
          if mode != "0"
            Smartware::Logging.logger.warn "USSD completed with mode #{mode}, expected 0"
          end

          if string
            @balance = string.scan(/\w{4}/)
            .map! { |i| [ i.hex ].pack("U") }
            .join
            .strip
          else
            @balance = nil
          end
        end

        private

        def modem_tick
          case @state
          when :closed
            Smartware::Logging.logger.info "trying to open modem"

            begin
              @mux = CMUX::MUX.new @config["device"]
              @state = :open
              @status_channel = @mux.allocate(@config["status_channel"]).open
              @chatter = CMUX::ModemChatter.new @status_channel
              @chatter.subscribe "CUSD", self
              @error = false
              @ussd_interval = 0
              Smartware::Logging.logger.info "modem ready"
            rescue => e
              close_modem "unable to open modem: #{e}"
            end

          when :open
            modem_works = nil

            begin
              @chatter.command("+CGMM;+CSQ", 3) do |resp|
                modem_works = resp.success?

                if modem_works
                  resp.response.reject! &:empty?
                  @model, @signal = resp.response
                end
              end

              while modem_works.nil?
                CMUX::ModemChatter.poll [ @chatter ]
              end
            rescue => e
              modem_works = false
            end

            if modem_works
              if @config.include?("balance_ussd") && @ussd_interval == 0
                @ussd_interval = @config["balance_interval"]
                begin
                  @chatter.command("+CUSD=1,\"#{@config["balance_ussd"]}\",15", 1)
                rescue => e
                  close_modem "USSD request failed: #{e}"
                end
              else
                @ussd_interval -= 1
              end
            else
              close_modem "modem is not responding"
            end
          end
        end

        def ppp_tick
          case @ppp_state
          when :stopped
            if @state == :open
              Smartware::Logging.logger.info "trying to start pppd"
              begin
                @ppp_channel = @mux.allocate @config["ppp_channel"]

                @ppp_pid = Process.spawn "smartware-ppp-helper",
                    @ppp_channel.device,
                    @config["apn"]
                @ppp_state = :running

                Smartware::Logging.logger.info "started pppd, PID #{@ppp_pid}"
                Smartware::ProcessManager.track @ppp_pid, method(:ppp_died)

              rescue => e
                begin
                  @ppp_channel.close
                rescue
                end

                @ppp_channel = nil
                @ppp_pid = nil
                @ppp_state = :stopped

                Smartware::Logging.logger.warn "cannot start pppd: #{e.to_s}"
              end
            end

          when :running
            if @ppp_pid.nil?
              Smartware::Logging.logger.warn "pppd died"
              begin
                @ppp_channel.close
              rescue
              end

              @ppp_channel = nil
              @ppp_state = :stopped
            end
          end
        end

        def ppp_died(pid)
          # will be handled by the event loop a moment later
          @ppp_pid = nil
        end

        def wait_for_event
          if @state == :open
            begin
              CMUX::ModemChatter.poll [ @chatter ], @config["poll_interval"]
            rescue => e
              close_modem "modem poll failed: #{e}"
            end
          else
            sleep @config["poll_interval"]
          end

        end

        def close_modem(reason)
          Smartware::Logging.logger.warn "#{reason}"

          @error = reason

          begin
            @mux.close
          rescue
          end

          begin
            @chatter.unsubscribe "CUSD", self
          rescue
          end

          @info_requested = false
          @mux = nil
          @chatter = nil
          @status_channel = nil
          @ppp_state = :stopped
          unless @ppp_pid.nil?
            Smartware::ProcessManager.untrack @ppp_pid
            @ppp_pid = nil # PPP will die by itself, because we closed the mux.
          end
          @state = :closed
        end
      end
    end
  end
end
