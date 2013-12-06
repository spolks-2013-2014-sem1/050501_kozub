require 'socket'
require 'benchmark'
require 'securerandom'
require '../libs/NetUtils.rb'

hostname = ARGV[0] || '127.0.0.1' 
port = ARGV[1] || 4455
filename = ARGV[2] || '../out84mb.pdf'
mode = ARGV[3] || 'udp'
PEEK_BUFFER_SIZE = 1024 * 64 / 8

CONNECTION_TIMEOUT = 10

connections = {}

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
    loop do
      rs, ws, es = IO.select([socket], nil, nil, CONNECTION_TIMEOUT)
      break unless rs
        
      rs.each do |s|
        data, sender_addrinfo = s.recvfrom(PEEK_BUFFER_SIZE)
        s.send("ACK", 0, sender_addrinfo)   
               
        ip = sender_addrinfo.ip_unpack
          
        connections[ip] = File.open(filename + "-#{SecureRandom.hex}", "w") unless connections[ip]
          
        if data.empty? || data == "FIN"
          puts "File transfer completed. File created: " + File.basename(connections[ip])
          connections[ip].close
          connections.delete(ip)            
          next
        end
          
        connections[ip].write(data)
      end     
    end
# ============================================= TCP Section  
  else
    loop do
      urgent_arr = []
      connections.each do |client_socket, data|
        urgent_arr.push(client_socket) if data[:read_oob]
      end
        
      rs, ws, us = IO.select(connections.keys + [socket], nil, urgent_arr, CONNECTION_TIMEOUT)
      break unless rs or us
        
      if rs.include?(socket)
        rs.delete(socket)
        client_socket, client_addrinfo = socket.accept

        connections[client_socket] = { 
          file: File.open(filename + "-#{SecureRandom.hex}", "w"), 
          recv: 0, 
          read_oob: true,
          }
      end
        
      rs.each do |s|
        attached = connections[s]
        data = s.recv(PEEK_BUFFER_SIZE)
          
        if data.empty?
          s.close
          attached[:file].close
          connections.delete(s)
          puts "File transfer completed. File created: " + File.basename(attached[:file])
          next
        end
          
        attached[:recv] += data.length
        attached[:read_oob] = true
        attached[:file].write(data)
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
    connections.each do |ip, file|
      file.close if file
    end
  else
    connections.each do |client_socket, attached|
      client_socket.close if client_socket
      attached[:file].close if attached[:file]
    end
  end   
end
