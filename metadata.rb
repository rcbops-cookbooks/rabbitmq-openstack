name              "rabbitmq-openstack"
maintainer        "Rackspace US, Inc."
license           "Apache 2.0"
description       "Makes the rabbitmq cookbook behave correctly with OpenStack"
version           IO.read(File.join(File.dirname(__FILE__), 'VERSION'))

%w{ centos ubuntu }.each do |os|
  supports os
end

%w{ keepalived osops-utils openssl }.each do |dep|
  depends dep
end

depends "rabbitmq", ">= 1.8.1"
