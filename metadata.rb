maintainer        "Rackspace US, Inc."
license           "Apache 2.0"
description       "Makes the rabbitmq cookbook behave correctly with OpenStack"
version           "1.0.13"

%w{ centos ubuntu }.each do |os|
  supports os
end

%w{ keepalived monitoring osops-utils openssl }.each do |dep|
  depends dep
end

depends "rabbitmq", ">= 1.8.1"
