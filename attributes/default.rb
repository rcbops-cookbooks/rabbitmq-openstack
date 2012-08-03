default['rabbitmq']['services']['queue']['scheme'] = "tcp"
default['rabbitmq']['services']['queue']['port'] = "5672"
default['rabbitmq']['services']['queue']['network'] = "nova"

case platform
when "fedora", "redhat"
  default["rabbitmq"]["platform"] = {
    "rabbitmq_service" => "rabbitmq-server",
    "rabbitmq_service_regex" => "-config /etc/rabbitmq/rabbitmq"
  }
when "ubuntu"
  default["rabbitmq"]["platform"] = {
    "rabbitmq_service" => "rabbitmq-server",
    "rabbitmq_service_regex" => "-config /etc/rabbitmq/rabbitmq"
  }
end
