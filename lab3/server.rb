require 'socket'
require 'benchmark'
require '../libs/NetUtils.rb'

hostname = ARGV[0] || '127.0.0.1' 
port = ARGV[1] || 4455
filename = ARGV[2] || '../in84mb.pdf'
file_size = File.size(filename)
aMB = 1024 * 1024
BUFFER_SIZE = aMB

socket = NetUtils::TCPServer.new(port, hostname)
puts "Server is running on #{hostname}:#{port}. Awaiting connections."

begin
  client_socket, client_addrinfo = socket.accept
rescue SystemExit, Interrupt => e
  puts "\nServer is shutting down."
  socket.close
  exit
end

puts "File transfer started."
begin
  time = Benchmark.realtime do
    File.open(filename, 'rb') do |file|
      while data = file.read(BUFFER_SIZE) do
        client_socket.write(data)
      end
    file.close
    end
  end
  
  puts "File transfer completed. Time elapsed: #{time} sec. Transfered #{file_size} MB of data. Average speed: #{file_size / time} MB/sec"

rescue SystemExit, Interrupt => e
  puts puts "\nFile transfer was interrupted by user."
rescue
  puts "File transfer failed!"
ensure
  client_socket.close
  socket.close
end
