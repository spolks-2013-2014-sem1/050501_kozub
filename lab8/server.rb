require 'socket'
require 'benchmark'
require 'securerandom'
require 'process_shared'
require '../libs/NetUtils.rb'

hostname = ARGV[0] || '127.0.0.1' 
port = ARGV[1] || 4455
filename = ARGV[2] || '../out84mb.pdf'
mode = ARGV[3] || 'tcp'
PEEK_BUFFER_SIZE = 1024 * 64 / 8
OOB_BUFFER_SIZE = 1

CONNECTION_TIMEOUT = 10

file = 0
connections = {}
processes = []
num = 4 #max number of active threads

packet = NetUtils::Packet.new
mutex = Mutex.new
mem = ProcessShared::SharedMemory.new(65535)
mem.write_object({})

if(mode == 'udp')
  socket = NetUtils::UDPServer.new(port, hostname)
  puts "Server is running on #{hostname}:#{port} in UDP mode."
else
  socket = NetUtils::TCPServer.new(port, hostname)
  puts "Server is running on #{hostname}:#{port} in TCP mode. Awaiting connections."
end

done = false

begin
  if(mode == 'udp')
    (1..num).each do
      processes << fork do
        begin
          loop do
            rs, ws, es = IO.select([socket], nil, nil, CONNECTION_TIMEOUT)
            break unless rs
        
            rs.each do |s|
              data, sender_addrinfo = s.recvfrom_nonblock(NetUtils::CHUNK_SIZE) rescue nil
              next unless sender_addrinfo
            
              s.send("ACK", 0, sender_addrinfo)   
               
              ip = sender_addrinfo.ip_unpack.to_s
              next if data == "FIN"
            
              mutex.synchronize do
              begin
                file = nil
                connections = mem.read_object
                packet.read(data)
                unless connections[ip]
                  file_name = filename + "-#{SecureRandom.hex}"
                  connections[ip] =  { 
                    chunks: packet.chunks.to_s,
                    file: file_name }
                end
            
                file = file || File.open(connections[ip][:file], "w")
                file.seek(packet.seek * NetUtils::CHUNK_SIZE)
                file.write(packet.data)
                
                chunks = Integer(connections[ip][:chunks]) - 1
                connections[ip][:chunks] = chunks.to_s
                if chunks == 0
                  puts "File transfer completed. File created: " + File.basename(connections[ip][:file])
                  connections.delete(ip)
                  next
                end
              ensure
                mem.write_object(connections)
                file.close if file
              end
            end
          end
        end
      ensure
        socket.close if socket  
      end
    end
  end
  
  Process.waitall  
# ============================================= TCP Section  
  else
    Signal.trap 'CLD' do
      pid = Process.wait(-1)
      processes.delete(pid)
    end
    
    loop do
      rs, ws, es = IO.select([socket], nil, nil, CONNECTION_TIMEOUT)
      break unless rs
      
      client_socket, client_addrinfo = socket.accept
      
      processes << fork do
        begin
          socket.close
          file_name = filename + "-#{SecureRandom.hex}"
          file = File.open(file_name, "w")
          
          loop do        
            rs, ws, us = IO.select([client_socket], nil, nil, CONNECTION_TIMEOUT)      
            break unless rs or us
      
            rs.each do |s|
              data = s.recv(PEEK_BUFFER_SIZE)
          
              if data.empty?
                puts "File transfer completed. File created: " + File.basename(file_name)
                exit
              end
        
              file.write(data)
            end
          end
        ensure
          file.close if file
          client_socket.close if client_socket
        end 
      end
    end
  end
    
rescue SystemExit, Interrupt => e
  puts "\nInterrupted."
  done = false
rescue 
  puts "\nError."
  done = false
  raise
  exit
ensure
  if mode == 'tcp'
    socket.close if socket
  end   
  puts "Server is shutting down."
end
