[web]
%{ for ip in instances ~}
instance_${replace(ip, ".", "_")} ansible_host=${ip} ansible_user=${ansible_user}
%{ endfor ~}

[web:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="ssh -i ${ssh_key} -W %h:%p -q -o StrictHostKeyChecking=no ubuntu@${bastion_ip}"'
ansible_python_interpreter=/usr/bin/python3
