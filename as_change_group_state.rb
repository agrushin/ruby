#!/usr/bin/env ruby
# vim: ts=4 sts=4 sw=4 expandtab
# 
require 'rubygems'
require 'optparse'
require 'pp'
require 'aws-sdk'

$options = {}
op = OptionParser.new do |opts|
    opts.banner = "Usage: "
    opts.on('-l', '--list', "List statuses of auto scaling groups") { |setting| $options[:list] = setting }
    opts.on('-s', '--suspend', "Suspend auto scaling activity") { |setting| $options[:suspend] = setting }
    opts.on('-r', '--resume', "Resume auto scaling activity") { |setting| $options[:resume] = setting }
    opts.separator("")
    opts.separator("Options: ")
    opts.on('-g', '--asg-prefix ASG-PREFIX', 'Operate only on groups matched with ASG-PREFIX') { |setting| $options[:asgprefix] = setting }
    opts.separator("")
    opts.separator("Common options: ")
    opts.on('-z', '--availability-zone AZONE', 'AWS EC2 availability zone') { |setting| $options[:azone] = setting }
    opts.on('-t', '--test', '[TODO] Dont make any changes') { |setting| $options[:test] = setting }
    opts.on('-v', '--verbose', '[TODO] Run verbosily' ) { |setting| $options[:verbose] = setting }
    opts.on_tail('-h', '--help', '--usage', 'Show this usage message and quit.') { |setting| puts opts.help; exit }
end

begin op.parse! ARGV
    rescue OptionParser::InvalidOption => err
        puts err
        puts op
        exit 1
end

config_file = File.join(File.dirname(__FILE__), "as_change_group_state.yml")
unless File.exist?(config_file)
  puts <<END
To run the samples, put your credentials in as_change_group_state.yml as follows:

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

as_change_group_state.yml is formatted incorrectly.  Please use the following format:

access_key_id: YOUR_ACCESS_KEY_ID
secret_access_key: YOUR_SECRET_ACCESS_KEY
region: us-west-1
auto_scaling_endpoint: autoscaling.us-west-1.amazonaws.com

END
  exit 1
end


AWS.config( $config )

if $options[:list]
    as = AWS::AutoScaling.new
    as.groups.each do |asg|
        next if !$options[:asgprefix].nil? and !asg.name.include? $options[:asgprefix]
        if asg.suspended_processes.empty?
            printf "%s: All processes are active\n", asg.name
        else 
            asg.suspended_processes.each do | k, v |
                printf "%s: %s (%s)\n", asg.name, k, v
            end
        end
    end

elsif $options[:resume]
    as = AWS::AutoScaling.new
    printf "Resuming auto scaling processes on: "
    as.groups.each do |asg|
        next if !$options[:asgprefix].nil? and !asg.name.include? $options[:asgprefix]
        if !asg.suspended_processes.empty?
            printf "%s ", asg.name        
            asg.resume_all_processes
        end
    end
    printf "\nDone!\n"

elsif $options[:suspend]
    as = AWS::AutoScaling.new
    printf "Suspending auto scaling processes on: "
    as.groups.each do |asg|
        next if !$options[:asgprefix].nil? and !asg.name.include? $options[:asgprefix]
        if asg.suspended_processes.empty?
            printf "%s ", asg.name        
            asg.suspend_all_processes
        end
    end
    printf "\nDone!\n"

else
    puts op

end
