default['rabbitmq']['services']['queue']['scheme'] = "tcp"
default['rabbitmq']['services']['queue']['port'] = "5672"
default['rabbitmq']['services']['queue']['network'] = "management"

case platform
when "fedora", "redhat", "centos", "amazon", "scientific"
  default["rabbitmq"]["platform"] = {
    "rabbitmq_service" => "rabbitmq-server",
    "rabbitmq_service_regex" => "/etc/rabbitmq/rabbitmq",
    "service_bin" => "/sbin/service",
    "package_overrides" => ""
  }
when "ubuntu"
  default["rabbitmq"]["platform"] = {
    "rabbitmq_service" => "rabbitmq-server",
    "rabbitmq_service_regex" => "/etc/rabbitmq/rabbitmq",
    "service_bin" => "/usr/sbin/service",
    "package_overrides" => "-o Dpkg::Options::='--force-confold' -o Dpkg::Options::='--force-confdef'"
  }
end
