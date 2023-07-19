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

resource "hcloud_primary_ip" "main" {
  name          = var.subdomain
  datacenter    = "${var.server.location}-dc3"
  type          = "ipv6"
  assignee_type = "server"
  auto_delete   = true
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
    ipv6 = hcloud_primary_ip.main.id
  }
  user_data = <<EOF
#cloud-config

# Set the locale and timezone
locale: en_US.UTF-8
timezone: Europe/Berlin

# Update and upgrade packages
package_update: true
package_upgrade: true
package_reboot_if_required: false

# Manage the /etc/hosts file
manage_etc_hosts: true

# Install required packages
packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg-agent
  - software-properties-common
  - fail2ban
  - unattended-upgrades

# Add Docker GPG key and repository
runcmd:
  - echo "Creating /etc/apt/keyrings directory" && logger "Keyrings directory created"
  - install -m 0755 -d /etc/apt/keyrings
  - echo "Adding Docker GPG key" && logger "Docker GPG key added"
  - curl -fsSL --insecure https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  - chmod a+r /etc/apt/keyrings/docker.gpg
  - echo "Adding Docker repository" && logger "Docker repository added"
  - echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package lists and install Docker packages
  - echo "Updating package lists" && logger "Package lists updated"
  - apt-get update && logger "Package update completed"
  - echo "Installing Docker packages" && logger "Docker packages installation started"
  - apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && logger "Docker packages installed"

# Configure fail2ban and SSH server
  - echo "Configuring fail2ban" && logger "Fail2ban configured"
  - printf "[sshd]\nenabled = true\nbanaction = iptables-multiport" > /etc/fail2ban/jail.local
  - systemctl enable fail2ban

  - echo "Configuring SSH server" && logger "SSH server configured"
  - sed -i -e '/^\(#\|\)PermitRootLogin/s/^.*$/PermitRootLogin no/' /etc/ssh/sshd_config
  - sed -i -e '/^\(#\|\)PasswordAuthentication/s/^.*$/PasswordAuthentication no/' /etc/ssh/sshd_config
  - sed -i -e '/^\(#\|\)X11Forwarding/s/^.*$/X11Forwarding no/' /etc/ssh/sshd_config
  - sed -i -e '/^\(#\|\)MaxAuthTries/s/^.*$/MaxAuthTries 2/' /etc/ssh/sshd_config
  - sed -i -e '/^\(#\|\)AllowTcpForwarding/s/^.*$/AllowTcpForwarding no/' /etc/ssh/sshd_config
  - sed -i -e '/^\(#\|\)AllowAgentForwarding/s/^.*$/AllowAgentForwarding no/' /etc/ssh/sshd_config
  - sed -i -e '/^\(#\|\)AuthorizedKeysFile

  # Restart and enable Docker service
  - echo "Restarting Docker service" && logger "Docker service restarted"
  - systemctl restart docker
  - systemctl enable docker

# Configure users
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
