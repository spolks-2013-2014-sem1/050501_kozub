require 'socket'
require '../libs/NET_UTILS.rb'

hostname = ARGV[0].nil? ? 'localhost' : ARGV[0]
port = ARGV[1].nil? ? 4455 : ARGV[1]
filename = ARGV[2].nil? ? '../out84mb.pdf' : ARGV[2]
BUFFER_SIZE = 1024 * 1024

socket = NET_UTILS::TCPClient.new(port, hostname)
begin
file = File.open(filename, 'w')

  while data = socket.read(BUFFER_SIZE)
      file.write(data)
  end
  
rescue
  puts "File transfer failed!"
  file.close
  File.delete(filename)
  raise
end
