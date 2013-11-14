require 'socket'
require '../libs/NET_UTILS.rb'

hostname = ARGV[0] || '127.0.0.1'
port = ARGV[1] || 4455
filename = ARGV[2] || '../out84mb.pdf'
BUFFER_SIZE = 10

socket = NET_UTILS::TCPClient.new(port, hostname)

begin
  file = File.open(filename, 'w')

  while data = socket.read(BUFFER_SIZE) do
      file.write(data)
  end
  
rescue
  puts "File transfer failed!"
  File.delete(filename)
rescue Interrupt
  puts puts "\nFile transfer was interrupted by user."
  File.delete(filename)
ensure
  file.close
  socket.close
end
