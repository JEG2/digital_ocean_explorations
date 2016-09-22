alias DigitalOceanExplorations.DigitalOceanAPI

defmodule SSHResult do
  defstruct stdout: "", stderr: "", exit_status: nil
end

defmodule SSHCommand do
  defstruct command: nil, test: :exit_status, expected: 0

  def new(command) do
    %__MODULE__{command: command}
  end

  def new(command, test, expected) do
    %__MODULE__{command: command, test: test, expected: expected}
  end

  def check_sucess(
    %SSHCommand{test: :exit_status, expected: exit_status},
    %SSHResult{exit_status: exit_status}
  ), do: :ok
  def check_sucess(
    %SSHCommand{test: :command, expected: test_command},
    _ssh_result
  ), do: test_command
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
  def connect(ip_address) do
    :ssh.start
    {:ok, connection} = :ssh.connect(
      String.to_charlist(ip_address),
      22,
      user_dir: String.to_charlist(Path.expand("../priv/ssh", __DIR__)),
      silently_accept_hosts: true,
      user: 'root'
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
        error
    end
  end
  def run_commands(_connection, [ ]), do: :ok

  defp run_command(connection, ssh_command) do
    {:ok, channel} = :ssh_connection.session_channel(connection, :infinity)
    :success = :ssh_connection.exec(
      connection,
      channel,
      String.to_charlist(ssh_command.command),
      :infinity
    )
    ssh_result = SSHResultReader.read_results(connection, channel)
    SSHCommand.check_sucess(ssh_command, ssh_result)
  end
end

ip_address =
  DigitalOceanAPI.find_droplet!("elixir-launched")
  |> get_in([:networks, :v4, Access.at(0), :ip_address])

connection = SSH.connect(ip_address)
edit = SSHCommand.new(
  "sed -i -e 's/^#AuthorizedKeysFile/" <>
    "PubkeyAcceptedKeyTypes=+ssh-dss\\n" <>
    "#AuthorizedKeysFile/' /etc/ssh/sshd_config",
  :command,
  SSHCommand.new("grep 'PubkeyAcceptedKeyTypes=+ssh-dss' /etc/ssh/sshd_config")
)
restart = SSHCommand.new("service ssh restart")
SSH.run_commands(connection, [edit, restart])
