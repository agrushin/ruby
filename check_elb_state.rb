#!/usr/bin/env ruby
#
# * Nagios plugin to check AWS elastic load balancers status
#
require 'rubygems'
require 'optparse'
require 'pp'
require 'aws-sdk'

options = {}
op = OptionParser.new do |opts|
  opts.banner = "Usage: "
  opts.on('-L', '--elbname ELBNAME', 'AWS ELB name to check status for') { |setting| options[:elbname] = setting }
  opts.separator("")
  opts.separator("Options: ")
  opts.on('-w', '--warning WARNING', 'Return warning if unhealthy hosts number greater than THRESHOLD (NUMBER:PERCENT)') { |setting| options[:warning] = setting }
  opts.on('-c', '--critical CRITICAL', 'Return critical if unhealthy hosts number greater than THRESHOLD (NUMBER:PERCENT)') { |setting| options[:critical] = setting }
  opts.on('-h', '--help', '--usage', 'Show this usage message and quit.') { |setting| puts opts.help; exit }
end

begin op.parse! ARGV
  rescue OptionParser::InvalidOption, OptionParser::MissingArgument => err
    puts err, op
    exit 3
end

begin
  raise OptionParser::MissingArgument, "-L | --elbname" if options[:elbname].nil?
  rescue OptionParser::MissingArgument => err
    puts err, op
    exit 3
end

config_file = File.join(File.dirname(__FILE__), "check_elb_state.yml")
unless File.exist?(config_file)
  puts <<END
To run the samples, put your credentials in check_elb_state.yml as follows:

access_key_id: YOUR_ACCESS_KEY_ID
secret_access_key: YOUR_SECRET_ACCESS_KEY
region: us-west-1
elasticloadbalancing_endpoint: elasticloadbalancing.us-west-1.amazonaws.com

END
  exit 1
end

$config = YAML.load(File.read(config_file))
unless $config.kind_of?(Hash)
  puts <<END

check_elb_state.yml is formatted incorrectly.  Please use the following format:

access_key_id: YOUR_ACCESS_KEY_ID
secret_access_key: YOUR_SECRET_ACCESS_KEY
region: us-west-1
elasticloadbalancing_endpoint: elasticloadbalancing.us-west-1.amazonaws.com

END
  exit 1
end

AWS.config( $config )
elb = AWS::ELB.new

begin
  instances = elb.load_balancers[options[:elbname]].instances.health
  instances_count = instances.count

rescue AWS::ELB::Errors::LoadBalancerNotFound => err
  puts "ELB UNKNOWN: #{options[:elbname]} not found (#{err})"
  exit 3
end

states = { 'InService' => [] }
instances.each do |instance|
  states[instance[:state]] = [] unless states.has_key?(instance[:state])
  states[instance[:state]].push(instance[:instance].id)
end

message = ""
thresholds = {}
return_code = 0

if states['InService'].count < instances_count
  (thresholds[:warning_number], thresholds[:warning_percent]) = options[:warning].split(':') if options[:warning]
  (thresholds[:critical_number], thresholds[:critical_percent]) = options[:critical].split(':') if options[:critical]
  [:warning_number, :warning_percent, :critical_number, :critical_percent].each { |st| thresholds[st] = nil if thresholds[st] == '' }

  unhealthy_count = instances_count - states['InService'].count
  unhealthy_percent = ((instances_count - states['InService'].count) * 100) / instances_count

  if (!thresholds[:critical_number].nil? && unhealthy_count >= thresholds[:critical_number].to_i) || \
    (!thresholds[:critical_percent].nil? && unhealthy_percent >= thresholds[:critical_percent].to_i)
    return_code = 2
    message = "CRITICAL: "
    states.each { |state,members| message << " #{state}: " + members.join(', ') unless members.empty? }

  elsif (!thresholds[:warning_number].nil? && unhealthy_count >= thresholds[:warning_number].to_i) || \
    (!thresholds[:warning_percent].nil? && unhealthy_percent >= thresholds[:warning_percent].to_i)
    return_code = 1
    message = "WARNING: "
    states.each { |state,members| message << " #{state}: " + members.join(', ') unless members.empty? }
  else
    return_code = 2
    message = "CRITICAL: "
    states.each { |state,members| message << " #{state}: " + members.join(', ') unless members.empty? }
  end

else
  message = "OK | "
  states.each { |state,members| message << " #{state}: " + members.join(', ') unless members.empty? }

end

puts "ELB #{message}"
exit return_code
