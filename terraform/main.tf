data "hetznerdns_zone" "dns_zone" {
  name = var.zone
}

resource "hcloud_firewall" "firewall" {
  name = var.subdomain
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

}


# Create server for deployment
resource "hcloud_server" "main" {
  name         = var.server.name
  image        = var.server.image
  server_type  = var.server.server_type
  location     = var.server.location
  backups      = var.server.backups
  firewall_ids = [hcloud_firewall.firewall.id]
  public_net {
    ipv4_enabled = false
    ipv6_enabled = true
  }
  user_data = <<EOF
#cloud-config
locale: en_US.UTF-8
timezone: Europe/Berlin
package_update: true
package_upgrade: true
package_reboot_if_required: false
manage_etc_hosts: true
locale: en_US.UTF-8
timezone: Europe/Berlin


packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg-agent
  - software-properties-common
  - fail2ban
  - unattended-upgrades

runcmd:
  - install -m 0755 -d /etc/apt/keyrings
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  - chmod a+r /etc/apt/keyrings/docker.gpg
  - echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  - apt-get update -y
  - apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin a
  - sudo apt-add-repository ppa:ansible/ansible
  - sudo apt install ansible
  - printf "[sshd]\nenabled = true\nbanaction = iptables-multiport" > /etc/fail2ban/jail.local
  - systemctl enable fail2ban
  - apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  - sed -i -e '/^\(#\|\)PermitRootLogin/s/^.*$/PermitRootLogin no/' /etc/ssh/sshd_config
  - sed -i -e '/^\(#\|\)PasswordAuthentication/s/^.*$/PasswordAuthentication no/' /etc/ssh/sshd_config
  - sed -i -e '/^\(#\|\)X11Forwarding/s/^.*$/X11Forwarding no/' /etc/ssh/sshd_config
  - sed -i -e '/^\(#\|\)MaxAuthTries/s/^.*$/MaxAuthTries 2/' /etc/ssh/sshd_config
  - sed -i -e '/^\(#\|\)AllowTcpForwarding/s/^.*$/AllowTcpForwarding no/' /etc/ssh/sshd_config
  - sed -i -e '/^\(#\|\)AllowAgentForwarding/s/^.*$/AllowAgentForwarding no/' /etc/ssh/sshd_config
  - sed -i -e '/^\(#\|\)AuthorizedKeysFile/s/^.*$/AuthorizedKeysFile .ssh\/authorized_keys/' /etc/ssh/sshd_config
  - sed -i '$a AllowUsers holu' /etc/ssh/sshd_config
  - systemctl daemon-reload
  - systemctl restart docker
  - systemctl enable docker

groups:
  - docker

users:
  - default
  - name: ${var.server.user}
    groups: sudo,docker
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    lock_passwd: true
    shell: /bin/bash
    ssh_authorized_keys:
    - ${file(var.ssh_key_path)}

final_message: "The system is ready, after $UPTIME seconds"

EOF
}

resource "hetznerdns_record" "main" {
  zone_id = data.hetznerdns_zone.dns_zone.id
  name    = var.subdomain
  value   = replace(hcloud_server.main.ipv6_address,"::/64",":1")
  type    = "AAAA"
  ttl     = 60
}

#####################

# writing data to files for ansible


resource "local_file" "ansible_inventory" {
  content = templatefile("inventory.tmpl",
    {
      ip   = hcloud_server.main.ipv6_address
      user = var.server.user
    }
  )
  filename = "../ansible/hosts"
}

resource "local_file" "group_vars" {
  content = templatefile("group_vars.tmpl",
    {
      domain = "${var.subdomain}.${var.zone}"
    }
  )
  filename = "../ansible/group_vars/main.yml"
}
