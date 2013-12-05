#
# Cookbook Name:: rabbitmq-openstack
# Recipe:: server
#
# Copyright 2012-2013, Rackspace US, Inc.
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

# set some rabbit attributes
node.set["rabbitmq"]["port"] = node["rabbitmq"]["services"]["queue"]["port"]
node.set["rabbitmq"]["address"] = get_ip_for_net(node['rabbitmq']['services']['queue']['network'])

# override upstream defaults
node.override["rabbitmq"]["tcp_listen_keepalive"] = true

# default to true for clustered rabbit
node.set["rabbitmq"]["cluster"] = true

# TODO(shep): Using the 'guest' user because it gets special permissions
#             we should probably setup different users for nova and glance
# TODO(shep): Should probably use Opscode::OpenSSL::Password for default_password
#

# default to using distro-provided packages for RHEL based systems since 3.x
# is in EPEL.  Otherwise we need to get it from rabbitmq.com
if platform_family?("rhel","fedora")
  node.override["rabbitmq"]["use_distro_version"] = true
else
  node.override["rabbitmq"]["use_distro_version"] = false
end

# need to build out [rabbitmq][cluster_disk_nodes] from a search of the nodes
# that include the rabbitmq-server role
node.set["rabbitmq"]["cluster_disk_nodes"] = osops_search(search_string="rabbitmq-server",one_or_all=:all,include_me=true,order=[:role]).map(&:hostname).map! { |k| "rabbit@#{k}" }

include_recipe "rabbitmq::default"

# TODO - this needs to be templated out
rabbitmq_user "add guest user" do
  user "guest"
  password "guest"
  action :add
end

rabbitmq_user "set guest user permissions" do
  user "guest"
  vhost "/"
  permissions '.* .* .*'
  action :set_permissions
end

rabbitmq_policy "ha-all" do
  pattern "^.*"
  params({"ha-mode"=>"all", "ha-sync-mode"=>"automatic"})
  priority 1
  action :set
end

rabbitmq_plugin "rabbitmq_management" do
  action :enable
  notifies :restart, "service[#{node['rabbitmq']['service_name']}]"
end

# is there a vip for us? if so, set up keepalived vrrp
if rcb_safe_deref(node, "vips.rabbitmq-queue")
  include_recipe "keepalived"
  vip = node["vips"]["rabbitmq-queue"]
  vrrp_name = "vi_#{vip.gsub(/\./, '_')}"
  if not vrrp_network = rcb_safe_deref(node, "vips_config_#{vip}_network","_")
    Chef::Application.fatal! "You have not configured a Network for the VIP.  Please set node[\"vips\"][\"config\"][\"#{vip}\"][\"network\"]"
  end
  vrrp_network = node["rabbitmq"]["services"]["queue"]["network"]
  #     real_servers get_bind_endpoint("rabbitmq", "queue", node)
  vrrp_interface = get_if_for_net(vrrp_network, node)
  src_ip = get_ip_for_net(vrrp_network, node)

  if router_id = rcb_safe_deref(node, "vips_config_#{vip}_vrid","_")
    Chef::Log.debug "using #{router_id} for vips.config.#{vip}.vrid"
  elsif router_id = rcb_safe_deref(node, "rabbitmq.ha.vrid")
    Chef::Application.fatal! "node[\"rabbitmq\"][\"ha\"][\"vrid\"] is deprecated.  Please set node[\"vips\"][\"config\"][\"#{vip}\"][\"vrid\"] instead"
  else
    Chef::Application.fatal! "You have not configured a VRID for the VIP.  Please set node[\"vips\"][\"config\"][\"#{vip}\"][\"vrid\"]"
  end

  keepalived_chkscript "rabbitmq" do
    script "#{platform_options["service_bin"]} rabbitmq-server status"
    interval 5
    action :create
  end

  keepalived_vrrp vrrp_name do
    interface vrrp_interface
    virtual_router_id router_id  # Needs to be a integer between 1..255
    track_script "rabbitmq"
    notify_master "/etc/keepalived/notify.sh add #{vrrp_interface} #{vip} #{src_ip}"
    notify_backup "/etc/keepalived/notify.sh del #{vrrp_interface} #{vip} #{src_ip}"
    notify_fault "/etc/keepalived/notify.sh del #{vrrp_interface} #{vip} #{src_ip}"
    notify_stop "/etc/keepalived/notify.sh del #{vrrp_interface} #{vip} #{src_ip}"
    notifies :restart, "service[keepalived]", :immediately
  end
end
