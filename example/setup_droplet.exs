alias DigitalOceanExplorations.DigitalOceanAPI
alias DigitalOceanExplorations.SSH.{CommandRunner, RawCommand}

ip_address =
  DigitalOceanAPI.find_droplet!("elixir-launched")
  |> get_in([:networks, :v4, Access.at(0), :ip_address])
user_name = "jeg2"
ssh_dir = "/Users/jeg2/.ssh"
ssh_keys = [
  "../priv/ssh/id_rsa.pub" |> Path.expand(__DIR__) |> File.read!,
  "/Users/jeg2/.ssh/id_dsa.pub" |> File.read!
]

connection = CommandRunner.connect(ip_address)

### Setup User
useradd = RawCommand.new("useradd -m #{user_name}")
make_ssh_dir = RawCommand.new("mkdir /home/#{user_name}/.ssh")
make_keys_file = RawCommand.new(
  "touch /home/#{user_name}/.ssh/authorized_keys"
)
chmod_ssh_dir = RawCommand.new("chmod 0700 /home/#{user_name}/.ssh")
chmod_keys_file = RawCommand.new(
  "chmod 0600 /home/#{user_name}/.ssh/authorized_keys"
)
add_keys = RawCommand.new(
  "cat - >> /home/#{user_name}/.ssh/authorized_keys",
  stdin: ssh_keys |> Enum.map(&String.trim/1) |> Enum.join("\n")
)
chown_ssh_dir = RawCommand.new(
  "chown -R #{user_name}:#{user_name} /home/#{user_name}/.ssh"
)
add_sudoer = RawCommand.new(
  "sed -i -e 's/^root\\tALL=(ALL:ALL) ALL$/" <>
    "root\\tALL=(ALL:ALL) ALL\\n" <>
    "#{user_name}\\tALL=(ALL) NOPASSWD: ALL/' /etc/sudoers",
  test: :command,
  expected: RawCommand.new(
    "grep '#{user_name}\tALL=(ALL) NOPASSWD: ALL' /etc/sudoers"
  )
)

### Configure SSH
disable_root_login = RawCommand.new(
  "sed -i -e 's/^PermitRootLogin yes$/PermitRootLogin no/' /etc/ssh/sshd_config",
  test: :command,
  expected: RawCommand.new("grep 'PermitRootLogin no' /etc/ssh/sshd_config")
)
disable_password_login = RawCommand.new(
  "sed -i -e 's/^#PasswordAuthentication yes$/" <>
    "PasswordAuthentication no/' /etc/ssh/sshd_config",
  test: :command,
  expected: RawCommand.new(
    "grep 'PasswordAuthentication no' /etc/ssh/sshd_config"
  )
)
allow_dsa_keys = RawCommand.new(
  "sed -i -e 's/^#AuthorizedKeysFile/" <>
    "PubkeyAcceptedKeyTypes=+ssh-dss\\n" <>
    "#AuthorizedKeysFile/' /etc/ssh/sshd_config",
  test: :command,
  expected: RawCommand.new(
    "grep 'PubkeyAcceptedKeyTypes=+ssh-dss' /etc/ssh/sshd_config"
  )
)
restart_ssh = RawCommand.new("service ssh restart")

CommandRunner.run_commands(connection, [
  useradd,
  make_ssh_dir,
  make_keys_file,
  chmod_ssh_dir,
  chmod_keys_file,
  add_keys,
  chown_ssh_dir,
  add_sudoer,
  disable_root_login,
  disable_password_login,
  allow_dsa_keys,
  restart_ssh
])

connection = CommandRunner.connect(
  ip_address,
  user: user_name,
  user_dir: ssh_dir
)

### Install Dependencies
update_apt_get = RawCommand.new("sudo apt-get update")
dist_upgrade = RawCommand.new("sudo apt-get dist-upgrade -y")
install_dependencies = RawCommand.new(
  "sudo apt-get install -y automake autoconf libreadline-dev " <>
    "libncurses-dev libssl-dev libyaml-dev libxslt-dev libffi-dev " <>
    "libtool unixodbc-dev"
)
reboot = RawCommand.new("sudo shutdown -r now", test: nil)

CommandRunner.run_commands(connection, [
  update_apt_get,
  dist_upgrade,
  install_dependencies,
  reboot
])
