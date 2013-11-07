default['rabbitmq']['services']['queue']['scheme'] = "tcp"          # node_attribute
default['rabbitmq']['services']['queue']['port'] = "5672"           # node_attribute
default['rabbitmq']['services']['queue']['network'] = "management"        # node_attribute

case platform
when "fedora", "redhat", "centos", "amazon", "scientific"
  default["rabbitmq"]["platform"] = {                               # node_attribute
    "rabbitmq_service" => "rabbitmq-server",
    "rabbitmq_service_regex" => "/etc/rabbitmq/rabbitmq",
    "service_bin" => "/sbin/service",
    "package_options" => ""
  }
when "ubuntu"
  default["rabbitmq"]["platform"] = {                               # node_attribute
    "rabbitmq_service" => "rabbitmq-server",
    "rabbitmq_service_regex" => "/etc/rabbitmq/rabbitmq",
    "service_bin" => "/usr/sbin/service",
    "package_options" => "-o Dpkg::Options::='--force-confold' -o Dpkg::Options::='--force-confdef'"
  }
end
