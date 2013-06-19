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
chef_gem "chef-rewind"
require 'chef/rewind'

include_recipe "osops-utils"
include_recipe "monitoring"
platform_options = node["rabbitmq"]["platform"]

# set some rabbit attributes
node.set["rabbitmq"]["port"] = node["rabbitmq"]["services"]["queue"]["port"]
# need to listen on all IPs so we can use a floating vip
node.set["rabbitmq"]["address"] = "0.0.0.0"

# TODO(shep): Using the 'guest' user because it gets special permissions
#             we should probably setup different users for nova and glance
# TODO(shep): Should probably use Opscode::OpenSSL::Password for default_password
#

# default to using distro-provided packages, otherwise we'll get 3.x.x from 
# rabbitmq.com
node.set["rabbitmq"]["use_distro_version"] = true

# are there any other rabbits out there? if so grab the cookie off them
if other_rabbit = get_settings_by_role("rabbitmq-server", "rabbitmq", false)
  node.set["rabbitmq"]["erlang_cookie"] = other_rabbit["erlang_cookie"]
  Chef::Log.info("getting erlang cookie from other rabbitmq node")
else
  node.set_unless["rabbitmq"]["erlang_cookie"] = secure_password
  Chef::Log.info("I am the only rabbitmq node - setting erlang cookie myself")
end

include_recipe "rabbitmq::default"

# sleep for 30s before restarting rabbitmq-server.  There is a race on new
# installs due to keepalived restarting rabbitmq-server on state transitions.
# this is a workaround until we get real clustered rabbitmq-server
# TODO(breu): remove this when clustered rabbitmq-server is done
rewind "service[rabbitmq-server]" do
#service "rabbitmq-server" do
  ignore_failure false
  retries 5
  restart_command "sleep 30s ; service rabbitmq-server restart"
end

# TODO(breu): commenting out for now.  this is a race condition
#
#if File.exists?(node['rabbitmq']['erlang_cookie_path'])
#  existing_erlang_key =  File.read(node['rabbitmq']['erlang_cookie_path'])
#else
#  existing_erlang_key = ""
#end
#
#if node['rabbitmq']['erlang_cookie'] != existing_erlang_key
#
#  template "/var/lib/rabbitmq/.erlang.cookie" do
#    cookbook "rabbitmq"
#    source "doterlang.cookie.erb"
#    owner "rabbitmq"
#    group "rabbitmq"
#    mode 0400
#  end
#
#  service "rabbitmq-server" do
#    action :restart
#    retries 5 # yes
#  end
#
#end

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

# is there a vip for us? if so, set up keepalived vrrp
if rcb_safe_deref(node, "vips.rabbitmq-queue")
  include_recipe "keepalived"
  vip = node["vips"]["rabbitmq-queue"]
  vrrp_name = "vi_#{vip.gsub(/\./, '_')}"
  vrrp_network = node["rabbitmq"]["services"]["queue"]["network"]
  vrrp_interface = get_if_for_net(vrrp_network, node)
  router_id = vip.split(".")[3]

  keepalived_chkscript "rabbitmq" do
    script "#{platform_options["service_bin"]} rabbitmq-server status"
    interval 5
    action :create
  end

  keepalived_vrrp vrrp_name do
    interface vrrp_interface
    virtual_ipaddress Array(vip)
    virtual_router_id router_id.to_i  # Needs to be a integer between 0..255
    track_script "rabbitmq"
    notify_backup "#{platform_options["service_bin"]} rabbitmq-server restart"
    notify_fault  "#{platform_options["service_bin"]} rabbitmq-server restart"
    notifies :run, "execute[reload-keepalived]", :immediately
  end

end
