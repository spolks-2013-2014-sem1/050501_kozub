require 'socket'
include Socket::Constants

module NetUtils
  DEFAULT_BACKLOG = 5
  
  class TCPServer < Socket
    def initialize(port, hostname)
      super(AF_INET, SOCK_STREAM, 0)
      setsockopt(SOL_SOCKET, SO_REUSEADDR, true)
      sockaddr = Socket.sockaddr_in(port, hostname)
      bind(sockaddr)
      listen(DEFAULT_BACKLOG)
    end
  end

  class TCPClient < Socket
    def initialize(port, hostname)
      super(AF_INET, SOCK_STREAM, 0)
      setsockopt(SOL_SOCKET, SO_REUSEADDR, true)
      sockaddr = Socket.sockaddr_in(port, hostname)
      begin
        connect(sockaddr)
      rescue
        $stdout.puts "Connection error."
        exit
      end
    end
  end
  
end
