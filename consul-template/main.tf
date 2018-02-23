resource "docker_image" "client" {
  name         = "${data.docker_registry_image.client_image.name}"
  keep_locally = true
}

resource "docker_image" "vault" {
  name         = "${data.docker_registry_image.vault_image.name}"
  keep_locally = true
}

resource "docker_image" "consul" {
  name         = "${data.docker_registry_image.consul_image.name}"
  keep_locally = true
}

resource "docker_network" "private_network" {
  name = "test_network"
}

resource "docker_container" "client" {
  image    = "${docker_image.client.name}"
  name     = "client.server"
  networks = ["${docker_network.private_network.id}"]

  ports {
    internal = 22
    external = 2222
  }

  provisioner "file" {
    connection {
      host     = "localhost"
      port     = "2222"
      user     = "root"
      password = "root"
    }

    source      = "files/"
    destination = "/root"
  }

  provisioner "file" {
    connection {
      host     = "localhost"
      port     = "2222"
      user     = "root"
      password = "root"
    }

    content     = "${data.template_file.chef_node_file.rendered}"
    destination = "/root/node.json"
  }

  provisioner "remote-exec" {
    connection {
      host     = "localhost"
      port     = "2222"
      type     = "ssh"
      user     = "root"
      password = "root"
    }

    inline = [
      "apt-get -y update",
      "apt-get -y install curl build-essential zlib1g-dev libssl-dev libreadline6-dev libyaml-dev zip unzip",
      "wget -O /tmp/ruby.tar.gz http://ftp.ruby-lang.org/pub/ruby/2.5/ruby-2.5.0.tar.gz",
      "cd /tmp",
      "tar -xvzf ruby.tar.gz",
      "cd /tmp/ruby-2.5.0/",
      "./configure --prefix=/usr/local",
      "make",
      "make install",
      "gem install berkshelf --no-ri --no-rdoc",
      "ln -s /opt/chef/embedded/bin/berks /usr/local/bin/berks",
      "curl -L https://omnitruck.chef.io/install.sh | bash",
      "mkdir -p /cookbooks",
      "berks vendor /cookbooks -b /root/Berksfile",
      "chef-client --local-mode -j /root/node.json",
      "wget -O /tmp/consul.zip https://releases.hashicorp.com/consul/1.0.6/consul_1.0.6_linux_amd64.zip",
      "unzip -d /usr/local/bin /tmp/consul.zip",
      "chmod 755 /usr/local/bin/consul",
    ]
  }
}

resource "docker_container" "vault" {
  image    = "${docker_image.vault.name}"
  name     = "vault.server"
  networks = ["${docker_network.private_network.id}"]
  command  = ["server"]
  env      = ["VAULT_LOCAL_CONFIG=${data.template_file.vault_config_file.rendered}"]

  capabilities {
    add = ["IPC_LOCK"]
  }
}

resource "docker_container" "consul" {
  image    = "${docker_image.consul.name}"
  name     = "consul.server"
  networks = ["${docker_network.private_network.id}"]
  command  = ["agent", "-server", "-bind", "0.0.0.0", "-client", "0.0.0.0", "-bootstrap-expect=1"]
}
