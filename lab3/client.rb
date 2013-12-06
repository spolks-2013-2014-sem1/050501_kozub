require 'socket'
require '../libs/NetUtils.rb'

hostname = ARGV[0] || '127.0.0.1'
port = ARGV[1] || 4455
filename = ARGV[2] || '../out84mb.pdf'
BUFFER_SIZE = 102

socket = NetUtils::TCPClient.new(port, hostname)

puts "File transfer started."

begin
  File.open(filename, 'w') do |file|
    while data = socket.read(BUFFER_SIZE) do
      file.write(data)
    end
    file.close
    puts "File transfer completed."
    break
  end
 
rescue SystemExit, Interrupt => e 
  puts puts "\nFile transfer was interrupted by user."
  File.delete(filename)
rescue
  puts "File transfer failed!"
  File.delete(filename)
ensure
  socket.close
end

