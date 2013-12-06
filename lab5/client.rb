require 'socket'
require 'benchmark'
require '../libs/NetUtils.rb'

hostname = ARGV[0] || '127.0.0.1' 
port = ARGV[1] || 4455
filename = ARGV[2] || '../in84mb.pdf'
mode = ARGV[3] || 'udp'
aMB = 1024 * 1024
PEEK_BUFFER_SIZE = 1024 * 64 / 8

CONNECTION_TIMEOUT = 10

if(mode == 'udp')
  socket = NetUtils::UDPClient.new(port, hostname)
  puts "Trying connection to #{hostname}:#{port}. UDP protocol."
else
  socket = NetUtils::TCPClient.new(port, hostname)
  puts "Trying connection to #{hostname}:#{port}. TCP protocol."
end


sent = true
done = false
File.open(filename, "r") do |file|
  begin
    if(mode == 'udp')
      loop do
        read_arr, write_arr = sent ? [[], [socket]] : [[socket], []]
        rs, ws, es = IO.select(read_arr, write_arr, nil, CONNECTION_TIMEOUT)
        break unless rs or ws
        break if sent and done
      
        data, sent = file.read(PEEK_BUFFER_SIZE), false if sent
      
        ws.each do |s|
          done, = data ? 
                  [false, s.send(data, 0)] :
                  [true, s.send("FIN", 0)]
        end
        
        rs.each do |s|
          sent = true if s.recv(3) == "ACK"
        end
      end
    else
      while data = file.read(PEEK_BUFFER_SIZE) do
        rs, ws, es = IO.select(nil, [socket], nil, CONNECTION_TIMEOUT)
        break unless ws
        ws.each do |s|
          s.send(data, 0)
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
  end
end
