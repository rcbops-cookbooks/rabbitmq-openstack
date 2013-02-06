maintainer        "Rackspace US, Inc."
license           "Apache 2.0"
description       "Makes the rabbitmq cookbook behave correctly with OpenStack"
version           "1.0.11"

%w{ ubuntu fedora }.each do |os|
  supports os
end

%w{ keepalived rabbitmq osops-utils openssl sysctl }.each do |dep|
  depends dep
end
