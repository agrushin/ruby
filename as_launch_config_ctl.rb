#!/usr/bin/env ruby
#
require 'rubygems'
require 'yaml'
require 'aws-sdk'
require 'pp'
require 'optparse'

$options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: "
  opts.on('-z', '--availability-zone AZONE', 'AWS EC2 availability zone') { |setting| $options[:azone] = setting }
  opts.on('-a', '--ami-prefix AMI-PREFIX', 'Search for fresh ami for given prefix description field') { |setting| $options[:amiprefix] = setting }
  opts.on('-A', '--ami-id IMAGE-ID', 'Image id') { |setting| $options[:amiid] = setting }
  opts.on('-g', '--as-group-prefix ASG-PREFIX', 'AutoScaling group prefix') { |setting| $options[:asgprefix] = setting }
  opts.on('-G', '--as-group-id ASG-ID', 'AutoScaling group identificator') { |setting| $options[:asgid] = setting }
  opts.on('-t', '--test', 'Dont make any changes') { |setting| $options[:test] = setting }
  opts.on('-v', '--verbose', 'Run verbosily' ) { |setting| $options[:verbose] = setting }
  opts.on_tail('-h', '--help', '--usage', 'Show this usage message and quit.') { |setting| puts opts.help; exit }
end.parse!

def info( severity, str )
  puts "#{severity}: #{str}" if $options[:verbose] == true
end

# http://docs.aws.amazon.com/AWSEC2/latest/APIReference/ApiReference-query-DescribeImages.html
# http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/EC2/Client/V20131001.html#describe_images-instance_method
def getImagesIdWithPrefix( amiprefix )

end

config_file = File.join(File.dirname(__FILE__), "as_launch_config_ctl.yml")
unless File.exist?(config_file)
    puts <<END
    To run the samples, put your credentials in as_launch_config_ctl.yml as follows:

    access_key_id: YOUR_ACCESS_KEY_ID
    secret_access_key: YOUR_SECRET_ACCESS_KEY
    region: us-west-1

END
      exit 1
end

$config = YAML.load(File.read(config_file))
unless $config.kind_of?(Hash)
    puts <<END

    as_launch_config_ctl.yml is formatted incorrectly.  Please use the following format:

    access_key_id: YOUR_ACCESS_KEY_ID
    secret_access_key: YOUR_SECRET_ACCESS_KEY
    region: us-west-1

END
  exit 1
end

fail "AMI prefix or AMI id not provided" unless $options[:amiprefix] or $options[:amiid]
fail "AutoScaling group name or prefix not provided" unless $options[:asgprefix] or $options[:asgid]
$options[:azone] = 'us-west-1a' if $options[:azone].nil?

AWS.config( $config )

ec2 = AWS::EC2.new( $config )

#info( 'I', 'test123')
