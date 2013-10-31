require 'socket'
require 'benchmark'
require '../libs/NET_UTILS.rb'

hostname = ARGV[0].nil? ? 'localhost' : ARGV[0]
port = ARGV[1].nil? ? 4455 : ARGV[1]
filename = ARGV[2].nil? ? '../in84mb.pdf' : ARGV[2]
aMB = 1024 * 1024
BUFFER_SIZE = aMB

socket = NET_UTILS::TCPServer.new(port, hostname)
puts "Server is running on #{hostname}:#{port}. Awaiting connections."

client_socket, client_addrinfo = socket.accept

puts "File transfer started."
begin
  time = Benchmark.realtime do
    file = File.open(filename, 'rb')
    while data = file.read(BUFFER_SIZE)
        client_socket.write(data)
    end
  end

rescue
  puts "File transfer failed!"
  raise
end

file_size = File.size(filename) / aMB
puts "File transfer completed. Time elapsed: #{time} sec. Transfered #{file_size} MB of data. Average speed: #{file_size / time} MB/sec"
