module Cramp
  module WebsocketExtension
    WEBSOCKET_RECEIVE_CALLBACK = 'websocket.receive_callback'.freeze

    def websocket?
      @env['HTTP_CONNECTION'] == 'Upgrade' && @env['HTTP_UPGRADE'] == 'WebSocket'
    end

    def secure_websocket?
      if @env.has_key?('HTTP_X_FORWARDED_PROTO')
        @env['HTTP_X_FORWARDED_PROTO'] == 'https' 
      else
        @env['HTTP_ORIGIN'] =~ /^https:/i
      end
    end

    def websocket_url
      scheme = secure_websocket? ? 'wss:' : 'ws:'
      @env['websocket.url'] = "#{ scheme }//#{ @env['HTTP_HOST'] }#{ @env['REQUEST_PATH'] }"
    end

    class WebSocketHandler
      def initialize(env, websocket_url, body)
        @env = env
        @websocket_url = websocket_url
        @body = body
      end
    end

    class Protocol75 < WebSocketHandler
      def handshake
        upgrade =  "HTTP/1.1 101 Web Socket Protocol Handshake\r\n"
        upgrade << "Upgrade: WebSocket\r\n"
        upgrade << "Connection: Upgrade\r\n"
        upgrade << "WebSocket-Origin: #{@env['HTTP_ORIGIN']}\r\n"
        upgrade << "WebSocket-Location: #{@websocket_url}\r\n\r\n"
        upgrade
      end
    end

    class Protocol76 < WebSocketHandler
      def handshake
        key1   = @env['HTTP_SEC_WEBSOCKET_KEY1']
        value1 = number_from_key(key1) / spaces_in_key(key1)

        key2   = @env['HTTP_SEC_WEBSOCKET_KEY2']
        value2 = number_from_key(key2) / spaces_in_key(key2)

        hash = Digest::MD5.digest(big_endian(value1) +
                                  big_endian(value2) +
                                  @body)

        upgrade =  "HTTP/1.1 101 Web Socket Protocol Handshake\r\n"
        upgrade << "Upgrade: WebSocket\r\n"
        upgrade << "Connection: Upgrade\r\n"
        upgrade << "Sec-WebSocket-Origin: #{@env['HTTP_ORIGIN']}\r\n"
        upgrade << "Sec-WebSocket-Location: #{@websocket_url}\r\n\r\n"
        upgrade << hash
        upgrade
      end

      private

      def number_from_key(key)
        key.scan(/[0-9]/).join('').to_i(10)
      end

      def spaces_in_key(key)
        key.scan(/ /).size
      end

      def big_endian(number)
        string = ''
        [24,16,8,0].each do |offset|
          string << (number >> offset & 0xFF).chr
        end
        string
      end
    end

  end
end
