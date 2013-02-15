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
  node.set["rabbitmq"]["erlang_cookie"] = other_rabbit["erlang_cookie"]
  Chef::Log.info("getting erlang cookie from other rabbitmq node")
else
  node.set_unless["rabbitmq"]["erlang_cookie"] = secure_password
  Chef::Log.info("I am the only rabbitmq node - setting erlang cookie myself")
end

include_recipe "rabbitmq::default"

# ugh. rabbit just won't die. We're overriding the restart command defined in
# the opscode cookbook
service "rabbitmq-server" do
  ignore_failure true
  retries 5
  restart_command "kill -9 $(pidof beam.smp) > /dev/null 2>&1 || true ; kill -9 $(pidof beam.smp) > /dev/null 2>&1 || true ; service rabbitmq-server start"
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
rabbitmq_user "guest" do
  password "guest"
  action :add
end

rabbitmq_user "guest" do
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
  vrrp_interface = get_if_for_net('public', node)
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
    notify_master "#{platform_options["service_bin"]} rabbitmq-server restart"
    notify_backup "#{platform_options["service_bin"]} rabbitmq-server restart"
    notify_fault "#{platform_options["service_bin"]} rabbitmq-server restart"
    notifies :restart, resources(:service => "keepalived")
  end

end
