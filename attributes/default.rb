default['rabbitmq']['services']['queue']['scheme'] = "tcp"
default['rabbitmq']['services']['queue']['port'] = "5672"
default['rabbitmq']['services']['queue']['network'] = "nova"

case platform
when "fedora", "redhat", "centos"
  default["rabbitmq"]["platform"] = {
    "rabbitmq_service" => "rabbitmq-server",
    "rabbitmq_service_regex" => "/etc/rabbitmq/rabbitmq",
    "package_overrides" => "",
  }
when "ubuntu"
  default["rabbitmq"]["platform"] = {
    "rabbitmq_service" => "rabbitmq-server",
    "rabbitmq_service_regex" => "/etc/rabbitmq/rabbitmq",
    "package_overrides" => "-o Dpkg::Options::='--force-confold' -o Dpkg::Options::='--force-confdef'"
  }
end
