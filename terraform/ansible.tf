resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/ansible_inventory.tpl", {
    instances   = module.compute.private_ips
    bastion_ip  = module.bastion.bastion_public_ip
    ssh_key     = var.ssh_key_path
    ansible_user = var.ansible_user
  })
  filename             = var.inventory_file
  directory_permission = "0777"
  file_permission      = "0777"
}
