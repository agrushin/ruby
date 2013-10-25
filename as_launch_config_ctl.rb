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
def getImagesFiltered( _ec2, _amiprefix )

  my_images = Hash.new
  my_images_filtered = _ec2.images.with_owner('self').filter("name", "#{_amiprefix} *")
  my_images_filtered.each { |image| my_images[image.image_id]=image.name.split(' ')[1].scan(/\d+$/).to_s }

  if $options[:verbose]
    puts "Available images: "
    my_images_sorted = my_images.sort { |a, b| a.last <=> b.last }
    my_images_sorted.each { |image, description| puts "#{image}: Description = #{my_images_filtered[image].name}" }
  end

  my_images
end

def getAutoScalingGroupsFiltered( _asgroups, _asgprefix )
  my_groups_filtered = Hash.new
  _asgroups.each { |group| my_groups_filtered[group.name]=group.launch_configuration_name if group.name.include? $options[:asgprefix].to_s }

  my_groups_filtered
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
as = AWS::AutoScaling.new( $config )

if $options[:amiprefix]
  puts "Trying to find image using AMI name filter " + $options[:amiprefix].to_s
  my_images_filtered = getImagesFiltered( ec2, $options[:amiprefix] )
  freshImage = my_images_filtered.max_by { |k,v| v }
  bestId = freshImage[0]
  puts "Image candidate: #{bestId}"
elsif $options[:amiid]
  puts "Using image specified in command line" + $options[:amiid].to_s
  img = ec2.images[$options[:amiid]]
  if img.exists?
    bestId = img.image_id
  else
    fail "Cannot find specified AMI"
  end
end

asgroups = as.groups
if $options[:asgprefix]
  puts "Trying to find AS groups list using filter " + $options[:asgprefix].to_s
  pp getAutoScalingGroupsFiltered( asgroups, $options[:asgprefix].to_s )
elsif $options[:asgid]
  puts "Using autoscaling group specified in command line" + $options[:asgid].to_s
end

puts "results: ami=#{bestId}"
