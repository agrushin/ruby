#!/usr/bin/env ruby
#
# ./check_asg_state.rb -H ASGNAME -r <REGION> -t|--maintenance-windows <"Mon 06:00-10:00;Tue 06:00-10:00;Wed 06:00-10:00;Tue 06:00-10:00;">
#
require 'rubygems'
require 'optparse'
require 'pp'
require 'aws-sdk'

options = {}
op = OptionParser.new do |opts|
  opts.banner = "Usage: "
  opts.on("-G", "--asgroup ASGNAME", "AWS AutoScaling Group name to check status for") { |setting| options[:asgname] = setting }
  opts.separator("")
  opts.separator("Options: ")
  opts.on('-t', '--maintenance-windows <weekDay startTime:stopTime>', 'Silently check (return OK during specified time periods specified in UTC).') { |setting| options[:maintenanceWindows] = setting }
  opts.on('-r', '--region <AWS_REGION>', 'Use AWS region (default: us-west-1)') { |setting| options[:region] = setting }
  opts.on('-h', '--help', '--usage', 'Show this usage message and quit.') { |setting| puts opts.help; exit }
  opts.on_tail.separator("")
  opts.on_tail.separator('Examples: ')
  opts.on_tail.separator('  check_asg_state.rb -G asg-cnn-nvuc0r-1 -t "Mon 06:00-10:00,16:00-17:00;Tue 06:00-10:00;Wed 06:00-10:00;Tue 06:00-10:00;"')
end

begin op.parse! ARGV
  rescue OptionParser::InvalidOption => err
    puts err, op
    exit 3
end

begin
  raise OptionParser::MissingArgument, "-G | --asgroup" if options[:asgname].nil?
  rescue OptionParser::MissingArgument => err
    puts err, op
    exit 3
end

config_file = File.join(File.dirname(__FILE__), "check_asg_state.yml")
unless File.exist?(config_file)
  puts <<END
To run the samples, put your credentials in check_asg_state.yml as follows:

access_key_id: YOUR_ACCESS_KEY_ID
secret_access_key: YOUR_SECRET_ACCESS_KEY
region: us-west-1
auto_scaling_endpoint: autoscaling.us-west-1.amazonaws.com

END
  exit 1
end

$config = YAML.load(File.read(config_file))
unless $config.kind_of?(Hash)
  puts <<END

check_asg_state.yml is formatted incorrectly.  Please use the following format:

access_key_id: YOUR_ACCESS_KEY_ID
secret_access_key: YOUR_SECRET_ACCESS_KEY
region: us-west-1
auto_scaling_endpoint: autoscaling.us-west-1.amazonaws.com

END
  exit 1
end

AWS.config( $config )
as = AWS::AutoScaling.new
asg = as.groups[options[:asgname]]

begin
  if asg.suspended_processes.empty?
    puts "OK: All processes are active"
    exit 0
  else
    puts "CRITICAL: #{asg.suspended_processes.keys.join(", ")} are not active"
    exit 2
  end
  rescue AWS::Core::Resource::NotFound => err
    puts "UNKNOWN: #{options[:asgname]} not found (#{err})"
    exit 3
end

