#!/usr/bin/env ruby
#
require 'rubygems'
require 'aws-sdk'
require 'logger'
require 'simple-graphite'

config_file = File.join(File.dirname(__FILE__), "as_send_stats_to_graphite.yml")
unless File.exist?(config_file)
  puts <<END
To run the samples, put your credentials in as_send_stats_to_graphite.yml as follows:

access_key_id: YOUR_ACCESS_KEY_ID
secret_access_key: YOUR_SECRET_ACCESS_KEY
region: us-west-1
auto_scaling_endpoint: autoscaling.us-west-1.amazonaws.com
graphite_host: graphite.local.tld
graphite_port: 2003
graphite_metric_prefix: aws.as

END
  exit 1
end

$config = YAML.load(File.read(config_file))
unless $config.kind_of?(Hash)
  puts <<END

as_send_stats_to_graphite.yml is formatted incorrectly.  Please use the following format:

access_key_id: YOUR_ACCESS_KEY_ID
secret_access_key: YOUR_SECRET_ACCESS_KEY
region: us-west-1
auto_scaling_endpoint: autoscaling.us-west-1.amazonaws.com
graphite_host: graphite.local.tld
graphite_port: 2003
graphite_metric_prefix: aws.as

END
  exit 1
end

AWS.config( $config )

stats = Hash.new{ |stats,k| stats[k] = Hash.new(0) }

as = AWS::AutoScaling.new
as.instances.each do |as_instance|
    sleep_duration = 1
    begin
      stats[as_instance.auto_scaling_group_name][as_instance.lifecycle_state.downcase] += 1
      stats[as_instance.auto_scaling_group_name][as_instance.health_status.downcase] += 1
    rescue => ex
      if sleep_duration < 65 
        puts "Error occured while dealing with #{as_instance.id}: #{ex.message}. Sleeping for #{sleep_duration} secs, then retry..."
        sleep(sleep_duration)
        sleep_duration *= 2
        retry
      else
        raise "Retry count exceeded"
      end
    end
end

gr = Graphite.new( { :host => $config["graphite_host"], :port => $config["graphite_port"] } )
stats.each do |sg_name,sg_stats|
  sg_stats.each do |state,count|
    gr.push_to_graphite do |graphite|
      sg_name_us = sg_name.tr('-', '_')
      graphite.puts $config["graphite_metric_prefix"]+".#{sg_name_us}.#{state} #{count} #{gr.time_now}"
    end
  end
end
