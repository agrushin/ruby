#!/usr/bin/env ruby
require 'yaml'

testarr={}
testarr['simple.normal.queue.name1'] = 100
testarr['simple.warning.queue.name'] = 10000
testarr['rexp.big.queue.name.bulk'] = 100000
testarr['sbulk1.huge.queue.name'] = 100000000

$config = YAML.load_file("check_amqp.yml")

$status_code = {}
$status_code["OK"] = 0
$status_code["WARNING"] = 1
$status_code["CRITICAL"] = 2
$status_code["UNKNOWN"] = 3

$state_code = $status_code["OK"]
$state_msg = ""

def raiseState( newstate, msg )
  if newstate == :critical    # -> CRITICAL
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

testarr.each do |queuename, size, type|

  thresholds = getQueueThresholds(queuename)

  if size > thresholds['general']['critical']
    raiseState(:critical, "C:#{queuename}:#{size} ")
  elsif size > thresholds['general']['warning']
    raiseState(:warning, "W:#{queuename}:#{size} ")
  end

end

puts "AMQP queues is #{$status_code.index($state_code)}: #{$state_msg}"
exit $state_code

