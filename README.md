check_amqp.rb: Nagios test for RabbitMQ queues.

Thresholds need to be specified in check_amqp.yml file. You ned to specify at least default thresholds.
But you can overwrite thresholds for queues using static names or regexp. Just take a look for example.
Then just run to get result:

<pre>
$ ./check_amqp.rb -H rabbitmq0.domain.tld
AMQP queues is OK:
</pre>

check_asg_state.rb: Nagios plugin to check AWS autoscaling group status. Maintenance windows supported
(periods then suspended groups is expected - e.g., during releases).

<pre>
$ ./check_asg_state.rb -G asg-test-0
OK: All processes are active

$ ./check_asg_state.rb -G asg-test-1
CRITICAL: HealthCheck, ReplaceUnhealthy, AZRebalance, Terminate, ScheduledActions, RemoveFromLoadBalancerLowPriority, AlarmNotification, Launch, AddToLoadBalancer suspended

$ ./check_asg_state.rb -G asg-test-1 -t "Tue 06:00-10:00;Wed 06:00-09:00,09:00-10:00;Fri 06:00-20:00;"
OK: RemoveFromLoadBalancerLowPriority, AZRebalance, ScheduledActions, ReplaceUnhealthy, AlarmNotification, Terminate, HealthCheck, Launch, AddToLoadBalancer suspended, but maintenance in progress
</pre>
