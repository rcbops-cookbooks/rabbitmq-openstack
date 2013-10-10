name              "rabbitmq-openstack"
maintainer        "Rackspace US, Inc."
license           "Apache 2.0"
description       "Makes the rabbitmq cookbook behave correctly with OpenStack"
version           "4.1.3"

%w{ centos ubuntu }.each do |os|
  supports os
end

%w{ keepalived osops-utils openssl }.each do |dep|
  depends dep
end

depends "rabbitmq", ">= 1.8.1"
