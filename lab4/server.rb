require 'socket'
require 'benchmark'
require '../libs/NetUtils.rb'

hostname = ARGV[0] || '127.0.0.1' 
port = ARGV[1] || 4455
filename = ARGV[2] || '../out84mb.pdf'
aMB = 1024 * 1024
BUFFER_SIZE = 102
PEEK_BUFFER_SIZE = 1024 / 8
OOB_BUFFER_SIZE = 1

CONNECTION_TIMEOUT = 10

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

File.open(filename, 'w') do |file|
  begin
    bytes_sent = 0
    done = false
    time = Benchmark.realtime do   
      loop do  
        break if done
        rs, ws, us = IO.select([client_socket], nil, [client_socket], CONNECTION_TIMEOUT)
        break unless rs
               
        rs.each do |s|
          data = s.recv(PEEK_BUFFER_SIZE)
          if data.empty?
            done = true
            break
          end
          bytes_sent += data.length
          file.write(data)
        end
            
        us.each do |s|
          data = s.recv(OOB_BUFFER_SIZE, MSG_OOB)        
          message = "#{bytes_sent} bytes sent."
          print message
          message.length.times {print "\r" }        
        end
      end
    end
    file_size = File.size(filename) / aMB
    puts "\nFile transfer completed. Time elapsed: #{time} sec. Transfered #{file_size} MB of data. Average speed: #{file_size / time} MB/sec"

  rescue SystemExit, Interrupt => e
    puts "\nInterrupted by user."
  rescue
    puts "File transfer failed!"
    raise
  ensure
    file.close if file
    client_socket.close if client_socket
    socket.close if socket
  end
end
