require 'socket'
require 'benchmark'
require '../libs/NetUtils.rb'

hostname = ARGV[0] || '127.0.0.1' 
port = ARGV[1] || 4455
filename = ARGV[2] || '../in84mb.pdf'
mode = ARGV[3] || 'tcp'
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

File.open(filename, "r") do |file|
  begin
    if(mode == 'udp')
      chunks = file.size / NetUtils::CHUNK_SIZE
      chunks += 1 unless file.size % NetUtils::CHUNK_SIZE == 0
      sent = true
      done = false
      seek = -1
      loop do
        read_arr, write_arr = sent ? [[], [socket]] : [[socket], []]
        rs, ws, es = IO.select(read_arr, write_arr, nil, CONNECTION_TIMEOUT)
        break unless rs or ws
        break if sent and done
      
        data, sent, seek = file.read(NetUtils::CHUNK_SIZE), false, seek + 1 if sent
      
        ws.each do |s|
          msg = NetUtils::Packet.new(seek: seek, chunks: chunks, len: data.length, data: data) if data
          done, = data ? 
                  [false, s.send(msg.to_binary_s, 0)] :
                  [true, s.send("FIN", 0)]
        end
        
        rs.each do |s|
          sent = true if s.recv(3) == "ACK"
        end
      end
# ============================================= TCP Section
    else
      while data = file.read(PEEK_BUFFER_SIZE) do
        rs, ws, es = IO.select(nil, [socket], nil, CONNECTION_TIMEOUT)
        break unless ws
        
        ws.each do |s|
          s.send(data, 0)
        end      
      end
        done = true
    end
    
  rescue SystemExit, Interrupt => e
    puts "\nInterrupted."
    done = false
  rescue 
    puts "Error."
    done = false
    raise
    exit
  ensure
    puts "File transfer completed." if done
    file.close if file
    socket.close if socket
  end
end
