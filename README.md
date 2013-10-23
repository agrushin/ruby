Nagios test for RabbitMQ queues.

Just declare your thresholds for queues in check_amqp.yml (you can use static names, regexp or just declare default). Then run:

$ ./check_amqp.rb -H rabbitmq0.domain.tld
AMQP queues is OK:
