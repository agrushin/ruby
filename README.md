Nagios test for RabbitMQ queues.

Usage:
Declare your thresholds for queues in check_amqp.yml, e.g.:

very_important_queue:
  general: { warning: 1000, critical: 1500 }
  unacked: { warning: 100, critical: 200 }
  
!ruby/regexp '/pipeline/':
    general: { warning: 20000, critical: 25000 }

default:
    general: { warning: 3000, critical: 6000 }
    unacked: { warning: 800, critical: 1000 }

Then run:

$ ./check_amqp.rb -H rabbitmq0.domain.tld
AMQP queues is OK:
