alias DigitalOceanExplorations.DigitalOceanAPI

defmodule SSHResult do
  defstruct stdout: "", stderr: "", exit_status: nil
end

defmodule SSHCommand do
  defstruct command: nil, data: nil, test: :exit_status, expected: 0

  def new(command, options \\ [ ]) do
    struct(__MODULE__, [{:command, command} | options])
  end

  def check_sucess(
    %SSHCommand{test: :exit_status, expected: exit_status},
    %SSHResult{exit_status: exit_status}
  ), do: :ok
  def check_sucess(
    %SSHCommand{test: :command, expected: test_command},
    _ssh_result
  ), do: test_command
  def check_sucess(%SSHCommand{test: nil}, nil), do: :ok
  def check_sucess(ssh_command, ssh_result) do
    {:error, ssh_command, ssh_result}
  end
end

defmodule SSHResultReader do
  @stdout 0
  @stderr 1

  def read_results(connection, channel) do
    read_results(connection, channel, %SSHResult{ })
  end

  defp read_results(
    connection,
    channel,
    result = %SSHResult{stdout: stdout, stderr: stderr}
  ) do
    receive do
      {:ssh_cm, ^connection, {:data, ^channel, @stdout, data}} ->
        new_result = %SSHResult{result | stdout: stdout <> data}
        read_results(connection, channel, new_result)
      {:ssh_cm, ^connection, {:data, ^channel, @stderr, data}} ->
        new_result = %SSHResult{result | stderr: stderr <> data}
        read_results(connection, channel, new_result)
      {:ssh_cm, ^connection, {:eof, ^channel}} ->
        read_results(connection, channel, result)
      {:ssh_cm, ^connection, {:exit_status, ^channel, exit_status}} ->
        new_result = %SSHResult{result | exit_status: exit_status}
        read_results(connection, channel, new_result)
      {:ssh_cm, ^connection, {:closed, ^channel}} ->
        result
    end
  end
end

defmodule SSH do
  @defaults [user: "root", user_dir: Path.expand("../priv/ssh", __DIR__)]

  def connect(ip_address, options \\ [ ]) do
    options = Keyword.merge(@defaults, options)
    :ssh.start
    {:ok, connection} = :ssh.connect(
      String.to_charlist(ip_address),
      22,
      user_dir: options |> Keyword.fetch!(:user_dir) |> String.to_charlist,
      silently_accept_hosts: true,
      user: options |> Keyword.fetch!(:user) |> String.to_charlist
    )
    connection
  end

  def run_commands(connection, [current_command | remaining_commands]) do
    case run_command(connection, current_command) do
      :ok ->
        run_commands(connection, remaining_commands)
      test_command = %SSHCommand{ } ->
        run_commands(connection, [test_command | remaining_commands])
      error ->
        :ok = :ssh.close(connection)
        IO.inspect(error)
    end
  end
  def run_commands(connection, [ ]) do
    :ok = :ssh.close(connection)
    :ok
  end

  defp run_command(connection, ssh_command) do
    {:ok, channel} = :ssh_connection.session_channel(connection, :infinity)
    :success = :ssh_connection.exec(
      connection,
      channel,
      String.to_charlist(ssh_command.command),
      :infinity
    )
    unless is_nil(ssh_command.data) do
      :ssh_connection.send(connection, channel, ssh_command.data)
      :ssh_connection.send_eof(connection, channel)
    end
    :ok = :ssh_connection.close(connection, channel)
    ssh_result =
      if ssh_command.test do
        SSHResultReader.read_results(connection, channel)
      else
        nil
      end
    SSHCommand.check_sucess(ssh_command, ssh_result)
  end
end

ip_address =
  DigitalOceanAPI.find_droplet!("elixir-launched")
  |> get_in([:networks, :v4, Access.at(0), :ip_address])
user_name = "jeg2"
ssh_dir = "/Users/jeg2/.ssh"
ssh_keys = [
  "../priv/ssh/id_rsa.pub" |> Path.expand(__DIR__) |> File.read!,
  "/Users/jeg2/.ssh/id_dsa.pub" |> File.read!
]

connection = SSH.connect(ip_address)

### Setup User
useradd = SSHCommand.new("useradd -m #{user_name}")
make_ssh_dir = SSHCommand.new("mkdir /home/#{user_name}/.ssh")
make_keys_file = SSHCommand.new(
  "touch mkdir /home/#{user_name}/.ssh/authorized_keys"
)
chmod_ssh_dir = SSHCommand.new("chmod 0700 /home/#{user_name}/.ssh")
chmod_keys_file = SSHCommand.new(
  "chmod 0600 /home/#{user_name}/.ssh/authorized_keys"
)
add_keys = SSHCommand.new(
  "cat - >> /home/#{user_name}/.ssh/authorized_keys",
  data: ssh_keys |> Enum.map(&String.trim/1) |> Enum.join("\n")
)
chown_ssh_dir = SSHCommand.new(
  "chown -R #{user_name}:#{user_name} /home/#{user_name}/.ssh"
)
add_sudoer = SSHCommand.new(
  "sed -i -e 's/^root\\tALL=(ALL:ALL) ALL$/" <>
    "root\\tALL=(ALL:ALL) ALL\\n" <>
    "#{user_name}\\tALL=(ALL) NOPASSWD: ALL/' /etc/sudoers",
  test: :command,
  expected: SSHCommand.new(
    "grep '#{user_name}\tALL=(ALL) NOPASSWD: ALL' /etc/sudoers"
  )
)

### Configure SSH
disable_root_login = SSHCommand.new(
  "sed -i -e 's/^PermitRootLogin yes$/PermitRootLogin no/' /etc/ssh/sshd_config",
  test: :command,
  expected: SSHCommand.new("grep 'PermitRootLogin no' /etc/ssh/sshd_config")
)
disable_password_login = SSHCommand.new(
  "sed -i -e 's/^#PasswordAuthentication yes$/" <>
    "PasswordAuthentication no/' /etc/ssh/sshd_config",
  test: :command,
  expected: SSHCommand.new(
    "grep 'PasswordAuthentication no' /etc/ssh/sshd_config"
  )
)
allow_dsa_keys = SSHCommand.new(
  "sed -i -e 's/^#AuthorizedKeysFile/" <>
    "PubkeyAcceptedKeyTypes=+ssh-dss\\n" <>
    "#AuthorizedKeysFile/' /etc/ssh/sshd_config",
  test: :command,
  expected: SSHCommand.new(
    "grep 'PubkeyAcceptedKeyTypes=+ssh-dss' /etc/ssh/sshd_config"
  )
)
restart_ssh = SSHCommand.new("service ssh restart")

SSH.run_commands(connection, [
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

connection = SSH.connect(ip_address, user: user_name, user_dir: ssh_dir)

### Install Dependencies
update_apt_get = SSHCommand.new("sudo apt-get update")
dist_upgrade = SSHCommand.new("sudo apt-get dist-upgrade -y")
install_dependencies = SSHCommand.new(
  "sudo apt-get install -y automake autoconf libreadline-dev " <>
    "libncurses-dev libssl-dev libyaml-dev libxslt-dev libffi-dev " <>
    "libtool unixodbc-dev"
)
reboot = SSHCommand.new("sudo shutdown -r now", test: nil)

SSH.run_commands(connection, [
  update_apt_get,
  dist_upgrade,
  install_dependencies,
  reboot
])
