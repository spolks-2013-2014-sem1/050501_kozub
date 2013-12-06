require 'socket'
require 'benchmark'
require '../libs/NetUtils.rb'

hostname = ARGV[0] || '127.0.0.1' 
port = ARGV[1] || 4455
filename = ARGV[2] || '../in84mb.pdf'
aMB = 1024 * 1024
PEEK_BUFFER_SIZE = 1024 / 8
OOB_BUFFER_SIZE = 1
bytes_sent = 0
CONNECTION_TIMEOUT = 10

socket = NetUtils::TCPClient.new(port, hostname)

File.open(filename, 'r') do |file|
  puts "File transfer started."
  begin
    bytes_sent = 0
    counter = 0
    done = false
      while data = file.read(PEEK_BUFFER_SIZE) do
        rs, ws, us = IO.select(nil, [socket], nil, CONNECTION_TIMEOUT)
        break unless ws
        
        ws.each do |s|
          s.send(data, 0)
          counter += 1
          bytes_sent += data.length
          if counter == 1024 / 8
            s.send('a', MSG_OOB)
            message = "#{bytes_sent} bytes sent."
            print message
            message.length.times {print "\r" }
            counter = 0
          end
        end 
      end
      done = true

  rescue SystemExit, Interrupt => e
    puts "\nInterrupted by user."
  rescue
    puts "\nFile transfer failed!"
    raise
  ensure
    puts "\nFile transfer completed." if done
    file.close if file
    socket.close if socket
  end
end
