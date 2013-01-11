#
# Cookbook Name:: rabbitmq-openstack
# Recipe:: server
#
# Copyright 2012, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

include_recipe "osops-utils"
platform_options = node["rabbitmq"]["platform"]

# Lookup endpoint info, and properly set rabbit attributes
#rabbit_info = get_bind_endpoint("rabbitmq", "queue")
#node.set["rabbitmq"]["port"] = rabbit_info["port"]
node.set["rabbitmq"]["port"] = node["rabbitmq"]["services"]["queue"]["port"]

#node.set["rabbitmq"]["address"] = rabbit_info["host"]
# need to listen on all IPs so we can use a floating vip
node.set["rabbitmq"]["address"] = "0.0.0.0"
#
#
# set some nice tcp timeouts for rabbitmq reconnects
include_recipe "sysctl::default"
sysctl_multi "rabbitmq" do
      instructions("net.ipv4.tcp_keepalive_time" => "30",
                   "net.ipv4.tcp_keepalive_intvl" => "1",
                   "net.ipv4.tcp_keepalive_probes" => "5")
end

# TODO(shep): Using the 'guest' user because it gets special permissions
#             we should probably setup different users for nova and glance
# TODO(shep): Should probably use Opscode::OpenSSL::Password for default_password
#

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

# are there any other rabbits out there? if so grab the cookie off them
if other_rabbit = get_settings_by_role("rabbitmq-server", "rabbitmq", false)
  node.set["rabbitmq"]["cluster"] = true
  node.set["rabbitmq"]["erlang_cookie"] = other_rabbit["erlang_cookie"]
  Chef::Log.info("getting erlang cookie from other rabbitmq node")
else
  node.set["rabbitmq"]["cluster"] = true
  node.set_unless["rabbitmq"]["erlang_cookie"] = secure_password
  Chef::Log.info("I am the only rabbitmq node - setting erlang cookie myself")
end

# is there a vip for us? if so, set up keepalived vrrp
if rcb_safe_deref(node, "rabbitmq.services.queue.vip")
  include_recipe "keepalived"
  vip = node["rabbitmq"]["services"]["queue"]["vip"]
  vrrp_name = "vi_#{vip.gsub(/\./, '_')}"
  vrrp_interface = get_if_for_net('public', node)
  router_id = vip.split(".")[3]

  keepalived_vrrp vrrp_name do
    interface vrrp_interface
    virtual_ipaddress Array(vip)
    virtual_router_id router_id.to_i  # Needs to be a integer between 0..255
    notify_master "/etc/init.d/rabbitmq-server restart"
    notify_backup "/etc/init.d/rabbitmq-server restart"
    notify_fault "/etc/init.d/rabbitmq-server restart"
    notifies :restart, resources(:service => "keepalived")
  end
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
