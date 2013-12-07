require 'socket'
require 'benchmark'
require 'securerandom'
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
threads = []
mutex = Mutex.new
num = 4 #max number of active threads

packet = NetUtils::Packet.new

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
      threads << Thread.new do
        loop do
          rs, ws, es = IO.select([socket], nil, nil, CONNECTION_TIMEOUT)
          break unless rs
        
          rs.each do |s|
            data, sender_addrinfo = s.recvfrom_nonblock(PEEK_BUFFER_SIZE) rescue nil
            next unless sender_addrinfo
            
            s.send("ACK", 0, sender_addrinfo)   
               
            ip = sender_addrinfo.ip_unpack.to_s
            next if data == "FIN"
            
            mutex.synchronize do
              packet.read(data)
              unless connections[ip]
                connections[ip] =  { 
                file: File.open(filename + 
                                "-#{SecureRandom.hex}", "w"),
                chunks: packet.chunks }
              end
            
              connections[ip][:file].seek(packet.seek * NetUtils::CHUNK_SIZE)
              connections[ip][:file].write(packet.data)
              connections[ip][:chunks] -= 1
            
              if connections[ip][:chunks] == 0
                puts "File transfer completed. File created: " + File.basename(connections[ip][:file])
                connections[ip][:file].close
                connections.delete(ip)
                next
              end
            end
          end
        end     
      end
    end
    
  threads.each(&:run)
  threads.each(&:join)
# ============================================= TCP Section  
  else
    loop do
      rs, ws, es = IO.select([socket], nil, nil, CONNECTION_TIMEOUT)
      break unless rs
      
      client_socket, client_addrinfo = socket.accept
      
      threads << Thread.new do
        begin
          file = File.open(filename + "-#{SecureRandom.hex}", "w")
          tsock = client_socket
          recv = 0
          has_oob = true
          
          loop do        
            urgent_arr = [tsock]
            rs, ws, us = IO.select([tsock], nil, urgent_arr, CONNECTION_TIMEOUT)      
            break unless rs or us
       
            us.each do |s|
              s.recv(OOB_BUFFER_SIZE, MSG_OOB)
              has_oob = false
            end
       
            rs.each do |s|
              data = s.recv(PEEK_BUFFER_SIZE)
          
              if data.empty?
                puts "File transfer completed. File created: " + File.basename(attached[:file])
                return
              end
          
              recv += data.length
              has_oob = true
        
              file.write(data)
            end
          end
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
  socket.close if socket
  if mode == 'udp'
    threads.each(&:exit)
    p connections
    connections.each do |ip, hash|
      hash[:file].close if file
    end
  else
    file.close if file
    mutex.synchronize do
      threads.delete(Thread.current)
    end
  end   
  puts "Server is shutting down."
end
