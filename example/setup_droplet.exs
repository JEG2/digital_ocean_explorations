alias DigitalOceanExplorations.DigitalOceanAPI

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

  def run_command(connection, command) do
    {:ok, channel} = :ssh_connection.session_channel(connection, :infinity)
    :success = :ssh_connection.exec(
      connection,
      channel,
      String.to_charlist(command),
      :infinity
    )
    SSHResultReader.read_results(connection, channel)
  end
end

defmodule SSHResult do
  defstruct stdout: "", stderr: "", exit_status: nil
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

ip_address =
  DigitalOceanAPI.find_droplet!("elixir-launched")
  |> get_in([:networks, :v4, Access.at(0), :ip_address])

connection = SSH.connect(ip_address)
SSH.run_command(connection, "pwd")
|> IO.inspect
