require 'socket'
require 'benchmark'
require '../libs/NetUtils.rb'

hostname = ARGV[0] || '127.0.0.1' 
port = ARGV[1] || 4455
filename = ARGV[2] || '../out84mb.pdf'
mode = ARGV[3] || 'udp'
aMB = 1024 * 1024
PEEK_BUFFER_SIZE = 1024 * 64 / 8

CONNECTION_TIMEOUT = 10

if(mode == 'udp')
  socket = NetUtils::UDPServer.new(port, hostname)
  puts "Server is running on #{hostname}:#{port} in UDP mode."
else
  socket = NetUtils::TCPServer.new(port, hostname)
  puts "Server is running on #{hostname}:#{port} in TCP mode. Awaiting connections."
  begin
  client_socket, client_addrinfo = socket.accept
  rescue SystemExit, Interrupt => e
    puts "\nServer is shutting down."
    socket.close
    exit
  end
  puts "Server is running on #{hostname}:#{port}."
end

done = false
File.open(filename, "w") do |file|
  begin
    if(mode == 'udp')
      loop do
        rs, ws, es = IO.select([socket], nil, nil, CONNECTION_TIMEOUT)
        break unless rs
        rs.each do |s|
          data, sender_addrinfo = s.recvfrom(PEEK_BUFFER_SIZE)
          s.send("ACK", 0, sender_addrinfo)
          if data.empty? || data == "FIN"
            done = true
            break
          end
          file.write(data)
        end     
      end
    else
      puts "File transfer started."
      loop do
        break if done
        rs, ws, es = IO.select([client_socket], nil, nil, CONNECTION_TIMEOUT)
        break unless rs
        rs.each do |s|
          data = s.recv(PEEK_BUFFER_SIZE)
          if data.empty?
            done = true
            break
          end
          file.write(data)
        end
      end
    end
  rescue SystemExit, Interrupt => e
    puts "\nInterrupted."
    done = false
  rescue 
    puts "Error."
    done = false
    exit
  ensure
    puts "File transfer completed." if done
    file.close if file
    socket.close if socket
    client_socket.close if client_socket
  end
end
