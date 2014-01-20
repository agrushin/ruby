#!/usr/bin/env ruby
#
# * Nagios plugin to check AWS autoscaling group status
#
require 'rubygems'
require 'optparse'
require 'pp'
require 'aws-sdk'
require 'date'

options = {}
op = OptionParser.new do |opts|
  opts.banner = "Usage: "
  opts.on("-G", "--asgroup ASGNAME", "AWS AutoScaling Group name to check status for") { |setting| options[:asgname] = setting }
  opts.separator("")
  opts.separator("Options: ")
  opts.on('-t', '--maintenance-windows <weekDay startTime:stopTime>', 'Silently check (return OK during specified time periods specified in UTC).') { |setting| options[:maintenanceWindows] = setting }
  opts.on('-h', '--help', '--usage', 'Show this usage message and quit.') { |setting| puts opts.help; exit }
  opts.on_tail.separator("")
  opts.on_tail.separator('Examples: ')
  opts.on_tail.separator('  check_asg_state.rb -G asg-testgroup-1 -t "Tue 06:00-10:00;Wed 06:00-09:00,09:00-10:00;Thu 06:00-10:00;"')
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

def isMaintenanceActiveNow?( maintenanceSchedule )
  now = Time.now.utc
  sched = {}
  maintenanceSchedule.split(";").each { |day| day.gsub(/(\w+)\s(.*)/) { sched[$1] = $2 } }
  if sched[Date::ABBR_DAYNAMES[now.wday]]
    sched[Date::ABBR_DAYNAMES[now.wday]].split(',').each do |tp|
      tstart = tstop = nil
      tp.gsub(/(([0-9]|0[0-9]|1[0-9]|2[0-3]):[0-5][0-9])\-(([0-9]|0[0-9]|1[0-9]|2[0-3]):[0-5][0-9])/) { tstart, tstop = $1, $3 }
      return (tstart..tstop).include?(now.strftime("%H:%M"))
    end
  end
end

AWS.config( $config )
as = AWS::AutoScaling.new
asg = as.groups[options[:asgname]]

begin
  if asg.suspended_processes.empty?
    puts "OK: All processes are active"
    exit 0
  else
    if options[:maintenanceWindows] && isMaintenanceActiveNow?(options[:maintenanceWindows])
      puts "OK: #{asg.suspended_processes.keys.join(", ")} suspended, but maintenance in progress"
      exit 0
    else
      puts "CRITICAL: #{asg.suspended_processes.keys.join(", ")} suspended"
      exit 2
    end
  end
  rescue AWS::Core::Resource::NotFound => err
    puts "UNKNOWN: #{options[:asgname]} not found (#{err})"
    exit 3
end

