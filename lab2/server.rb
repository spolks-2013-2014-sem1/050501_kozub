require 'socket'
include Socket::Constants

hostname = ARGV[0] || '127.0.0.1' 
port = ARGV[1] || 4455

socket = Socket.new(AF_INET, SOCK_STREAM, 0)
sockaddr = Socket.sockaddr_in(port, hostname)

socket.setsockopt(Socket::SOL_SOCKET,Socket::SO_REUSEADDR, true)
socket.bind(sockaddr)
puts "Server is running on #{hostname}:#{port}. Awaiting connections."
socket.listen(5)

client_fd, client_addrinfo = socket.sysaccept
client_socket = Socket.for_fd(client_fd)

loop do
  begin
    command = client_socket.gets
    if command.chomp == "quit" || command.nil?
      puts "Server is shutting down."
      client_socket.close
      socket.close
      break
    else   
      puts command.chomp
      client_socket.puts command
    end
  
  rescue
    puts "Server is shutting down."
    client_socket.close
    socket.close
    break
  end
end
