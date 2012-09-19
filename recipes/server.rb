
include_recipe "osops-utils"
platform_options = node["rabbitmq"]["platform"]

# Lookup endpoint info, and properly set rabbit attributes
rabbit_info = get_bind_endpoint("rabbitmq", "queue")
node.set["rabbitmq"]["port"] = rabbit_info["port"]
node.set["rabbitmq"]["address"] = rabbit_info["host"]

# TODO(shep): Using the 'guest' user because it gets special permissions
#             we should probably setup different users for nova and glance
# TODO(shep): Should probably use Opscode::OpenSSL::Password for default_password

case node["platform"]
# Since the upstream rabbitmq server does crazy things, like install packages from
# random apt repos.. lets pin to the ubuntu repo.
when "ubuntu", "debian"
  apt_preference "rabbitmq-server" do
    pin "release o=Ubuntu"
    pin_priority "700"
  end
# TODO(darren) do we want packages from rabbit site, or epel/distro?
# if the latter, then we can use the below to override the default in the
# opscode rabbitmq cookbook
#when "redhat", "centos", "fedora"
#  node.override["rabbitmq"]["use_yum"] = true
end

include_recipe "rabbitmq::default"

# TODO - this needs to be templated out
rabbitmq_user "guest" do
  password "guest"
  action :add
end

rabbitmq_user "guest" do
  vhost "/"
  permissions "\".*\" \".*\" \".*\""
  action :set_permissions
end

monitoring_procmon "rabbitmq-server" do
  service_name=platform_options["rabbitmq_service"]
  process_name platform_options["rabbitmq_service_regex"]
  script_name service_name
end

monitoring_metric "rabbitmq-server-proc" do
  type "proc"
  proc_name "rabbitmq-server"
  proc_regex platform_options["rabbitmq_service_regex"]

  alarms(:failure_min => 1.0)
end
