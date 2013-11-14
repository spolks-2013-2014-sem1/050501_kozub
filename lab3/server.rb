require 'socket'
require 'benchmark'
require '../libs/NET_UTILS.rb'

hostname = ARGV[0] || '127.0.0.1' 
port = ARGV[1] || 4455
filename = ARGV[2] || '../in84mb.pdf'
aMB = 1024 * 1024
BUFFER_SIZE = aMB

socket = NET_UTILS::TCPServer.new(port, hostname)
puts "Server is running on #{hostname}:#{port}. Awaiting connections."

client_socket, client_addrinfo = socket.accept

puts "File transfer started."
begin
  time = Benchmark.realtime do
    file = File.open(filename, 'rb')
    while data = file.read(BUFFER_SIZE) do
        client_socket.write(data)
    end
  end
  
  file_size = File.size(filename) / aMB
  puts "File transfer completed. Time elapsed: #{time} sec. Transfered #{file_size} MB of data. Average speed: #{file_size / time} MB/sec"

rescue
  puts "File transfer failed!"
rescue Interrupt
  puts puts "\nFile transfer was interrupted by user."
ensure
  client_socket.close
  socket.close
end
