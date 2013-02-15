require "chunky_png"
require "oily_png"

module Smartware
  module Driver
    module UserInterface
      class X11
        def initialize(config)
          @user = config["user"]
          @display = config["display"]
        end

        def delete_calibration
          File.delete "/home/#{@user}/.calibration_data" rescue nil
          File.delete "/home/#{@user}/.monitors" rescue nil
        end

        def restart_ui
          system "pkill", "-U", @config["user"], "xinit"
        end

        def screenshot
          mine_pipe, xwd_pipe = IO.pipe
          png = nil

          begin
            pid = Process.spawn({
              "DISPLAY"    => @display,
              "XAUTHORITY" => "/home/#{@user}/.Xauthority"
            }, "xwd", "-root", in: :close, out: xwd_pipe)

            xwd_pipe.close
            xwd_pipe = nil


            header_size, file_version,
            pixmap_format, pixmap_depth, pixmap_width, pixmap_height,
            xoffset, byteorder, bitmap_unit, bitmap_bit_order, bitmap_pad,
            bits_per_pixel, bytes_per_line, visual_class,
            red_mask, green_mask, blue_mask, bits_per_rgb,
            number_of_colors, color_map_entires,
            window_width, window_height, window_x, window_y, window_border_width =
              mine_pipe.read(4 * 25).unpack("N*")

            raise "Only direct color images are supported" if (visual_class != 5 && visual_class != 4)

            mine_pipe.read((header_size + number_of_colors * 12) - 4 * 25)

            initial = Array.new pixmap_width, pixmap_height

            case bits_per_pixel
            when 24
              0.upto(pixmap_height - 1) do |y|
                line = mine_pipe.read(bytes_per_line)
                                .slice(0, bits_per_pixel / 8 * pixmap_width)

                0.upto(pixmap_width - 1) do |x|
                  initial[y * pixmap_width + x] =
                      (line.getbyte(x * 3 + 2) << 24) |
                      (line.getbyte(x * 3 + 1) << 16) |
                      (line.getbyte(x * 3 + 0) << 8) |
                      0xFF
                end
              end

            when 32
              0.upto(pixmap_height - 1) do |y|
                line = mine_pipe.read(bytes_per_line)
                                .slice(0, bits_per_pixel / 8 * pixmap_width)

                0.upto(pixmap_width - 1) do |x|
                  pix, = line.slice(x * 4, 4).unpack("V")
                  initial[y * pixmap_width + x] = ((pix & 0xFFFFFF) << 8) | 0xFF
                end
              end

            else
              raise "Unsupported bpp: #{bits_per_pixel}"
            end

            png = ChunkyPNG::Image.new pixmap_width, pixmap_height, initial

            png.to_datastream.to_blob
          rescue => e
            "!error: #{e}"
          ensure
            mine_pipe.close
            xwd_pipe.close unless xwd_pipe.nil?
          end
        end
      end
    end
  end
end
