check_amqp.rb: Nagios test for RabbitMQ queues.

Thresholds need to be specified in check_amqp.yml file. You ned to specify at least default thresholds.
But you can overwrite thresholds for queues using static names or regexp. Just take a look for example.
Then just run to get result:

<pre>
$ ./check_amqp.rb -H rabbitmq0.domain.tld
AMQP queues is OK:
</pre>
