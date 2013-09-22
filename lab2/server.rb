require 'socket'
include Socket::Constants

hostname = ARGV[0].nil? ? 'localhost' : ARGV[0]
port = ARGV[1].nil? ? 4455 : ARGV[1]

socket = Socket.new(AF_INET, SOCK_STREAM, 0)
sockaddr = Socket.sockaddr_in(port, hostname)

socket.setsockopt(Socket::SOL_SOCKET,Socket::SO_REUSEADDR, true)
socket.bind(sockaddr)
puts "Server is running on #{hostname}:#{port}. Awaiting connections."
socket.listen(5)

client_fd, client_addrinfo = socket.sysaccept
client_socket = Socket.for_fd(client_fd)

loop {
  command = client_socket.gets.chomp
  if command == "quit"
    puts "Server is shutting down."
    client_socket.puts "Server is shutting down."
    socket.close
    break
  else
    puts command
  end
}
