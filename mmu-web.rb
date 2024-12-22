require 'sinatra'
require 'erb'

set :bind, '0.0.0.0'
set :port, 4567

get '/' do
  @statuses = parse_log_file('log.txt')
  @max_ip_length = @statuses.keys.map(&:length).max
  @max_status_length = @statuses.values.flatten.map { |record| record[:status].length }.max
  erb :index
end

get '/api/:ip' do
  ip = params[:ip]
  statuses = parse_log_file('log.txt')
  if statuses.key?(ip)
    content_type :json
    { ip: ip, records: statuses[ip], online_percentage: calculate_online_percentage(statuses[ip]) }.to_json
  else
    status 404
    { error: 'IP not found' }.to_json
  end
end

def parse_log_file(file_path)
  statuses = Hash.new { |hash, key| hash[key] = [] }
  File.readlines(file_path).each do |line|
    timestamp, ip, status = line.split(' - ')
    statuses[ip] << { status: status.strip, timestamp: timestamp }
    statuses[ip] = statuses[ip].last(15)
  end
  statuses
end

def calculate_online_percentage(records)
  online_count = records.count { |record| record[:status].downcase == 'online' }
  (online_count.to_f / records.size * 100).round(1)
end

__END__

@@index
<!DOCTYPE html>
<html>
<head>
  <style>
    .online { color: green; }
    .offline { color: red; font-weight: bold; }
    .history .online { color: green; }
    .history .offline { color: red; }
    body { width: 800px; margin: 0 auto; margin-top: 50px; }
  </style>
  <meta http-equiv="refresh" content="30">
</head>
<body>
  <div style="font-family: monospace;">
      <% @statuses.each do |ip, records| %>
        <span><%= ip.ljust(@max_ip_length).gsub(' ', '&nbsp;') %> <span class="<%= records.last[:status].downcase %>"><%= records.last[:status].ljust(@max_status_length).gsub(' ', '&nbsp;') %></span> [<span class="history">
          <% records.each do |record| %><span class="<%= record[:status].downcase %>" title="<%= record[:timestamp] %>">#</span><% end %>
        </span>] (Last ping: <%= records.last[:timestamp] %>) [last 15 <%= calculate_online_percentage(records) %>%]</span><br/>
      <% end %>
      
      <br/><br/>
      <b>info</b><br/>
      this site uses minimuptime (with mmu-web frontend) by <a href="https://github.com/hwiinet/minimuptime">hwii</a>.

      <br/><br/>
      each hash (#) represents a ping sent to the ip address. green ones are online, red ones are offline. you can hover over a specific hash to view its timestamp.
      
      <br/><br/>
      <b>api usage</b><br/>
      a simple api can be accessed at /api/:ip. it returns json data of the ip address with its last 15 records, and its online percentage. for example,
      http://<%= request.host_with_port %>/api/192.168.1.25
  </div>
</body>
</html>
