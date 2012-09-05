
include_recipe "osops-utils"
platform_options = node["rabbitmq"]["platform"]

# Lookup endpoint info, and properly set rabbit attributes
rabbit_info = get_bind_endpoint("rabbitmq", "queue")
node.set["rabbitmq"]["port"] = rabbit_info["port"]
node.set["rabbitmq"]["address"] = rabbit_info["host"]

# TODO(shep): Using the 'guest' user because it gets special permissions
#             we should probably setup different users for nova and glance
# TODO(shep): Should probably use Opscode::OpenSSL::Password for default_password

# Since the upstream rabbitmq server does crazy things, like install packages from
# random apt repos.. lets pin to the ubuntu repo.
case node["platform"]
when "ubuntu", "debian"
    apt_preference "rabbitmq-server" do
        pin "release o=Ubuntu"
        pin_priority "700"
    end
end

package "rabbitmq-server" do
   action :upgrade
   options platform_options["package_overrides"]
end

include_recipe "rabbitmq::default"

monitoring_procmon "rabbitmq-server" do
  service_name=platform_options["rabbitmq_service"]

  process_name platform_options["rabbitmq_service_regex"]
  start_cmd "/usr/sbin/service #{service_name} start"
  stop_cmd "/usr/sbin/service #{service_name} stop"
end

monitoring_metric "rabbitmq-server-proc" do
  type "proc"
  proc_name "rabbitmq-server"
  proc_regex platform_options["rabbitmq_service_regex"]

  alarms(:failure_min => 1.0)
end
