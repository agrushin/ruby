#!/usr/bin/env ruby
#
require 'yaml'
require 'optparse'
require 'net/http'
require 'uri'
require 'rubygems'
require 'json'

$config = YAML.load_file("check_amqp.yml")

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: check_amqp.rb [options]"
  opts.on('-H','--hostname FQDN','RabbitMQ server') { |v| options[:hostname] = v }
end.parse!

raise OptionParser::MissingArgument if options[:hostname].nil?

$status_code = {}
$status_code["OK"] = 0
$status_code["WARNING"] = 1
$status_code["CRITICAL"] = 2
$status_code["UNKNOWN"] = 3

$state_code = $status_code["OK"]
$state_msg = ""

def raiseState( newstate, msg )

  if newstate == :unknown
    $state_code = $status_code["UNKNOWN"]
    $state_msg << msg
  elsif newstate == :critical    # -> CRITICAL
    $state_code = $status_code["CRITICAL"]
    $state_msg << msg
  elsif newstate == :warning && $state_code == $status_code["OK"]   # ok -> WARNING
    $state_code = $status_code["WARNING"]
    $state_msg << msg
  else
    $state_msg << msg
  end

end

def getQueueThresholds( queueName )
  _threshold = $config['default']

  if $config[queueName]
    _threshold = $config[queueName]
  else
    $config.select { |k,v| k.class.to_s == "Regexp" }.each do |regexp,threshold|
      if queueName =~ regexp
        _threshold = threshold
      end
    end
  end

  return _threshold
end

# - RabbitMQ management API (http://hg.rabbitmq.com/rabbitmq-management/raw-file/rabbitmq_v3_1_5/priv/www/api/index.html)
uri = URI("http://#{options[:hostname]}:55672/api/queues?columns=name,messages,messages_unacknowledged")
http = Net::HTTP.new( uri.host, uri.port )
req = Net::HTTP::Get.new( uri.request_uri )
req.basic_auth( "guest", "guest" )

begin
  response = http.request(req)
  qlist = JSON.parse(response.body)
rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
  raiseState(:unknown, "#{e}")
end

if $state_code == $status_code["OK"]
  qlist.each do |q|
    thresholds = getQueueThresholds(q['name'])

    if q['messages'] > thresholds['general']['critical']
      raiseState(:critical, "C:#{q['name']}:#{q['messages']} ")
    elsif q['messages'] > thresholds['general']['warning']
      raiseState(:warning, "W:#{q['name']}:#{q['messages']} ")
    end

    if thresholds['unacked']
      if q['messages_unacknowledged'] > thresholds['unacked']['critical']
        raiseState(:critical, "UC:#{q['name']}:#{q['messages_unacknowledged']} ")
      elsif q['messages_unacknowledged'] > thresholds['unacked']['warning']
        raiseState(:warning, "UW:#{q['name']}:#{q['messages_unacknowledged']} ")
      end
    end

  end
end

puts "AMQP queues is #{$status_code.index($state_code)}: #{$state_msg}"
exit $state_code
