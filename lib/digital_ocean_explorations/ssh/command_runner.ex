defmodule DigitalOceanExplorations.SSH.CommandRunner do
  require Logger
  alias DigitalOceanExplorations.SSH.{RawCommand, ResultReader}

  @defaults [user: "root", user_dir: Path.expand("../../../priv/ssh", __DIR__)]

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
        Logger.info("Command succeeded.")
        run_commands(connection, remaining_commands)
      test_command = %RawCommand{ } ->
        Logger.info("Command completed.  Testing success...")
        run_commands(connection, [test_command | remaining_commands])
      error ->
        Logger.info("Command error:  #{inspect(error)}")
        :ok = :ssh.close(connection)
    end
  end
  def run_commands(connection, [ ]) do
    :ok = :ssh.close(connection)
    :ok
  end

  defp run_command(connection, ssh_command) do
    {:ok, channel} = :ssh_connection.session_channel(connection, :infinity)
    Logger.info("Executing command `#{ssh_command.command}`...")
    :success = :ssh_connection.exec(
      connection,
      channel,
      String.to_charlist(ssh_command.command),
      :infinity
    )
    unless is_nil(ssh_command.stdin) do
      :ssh_connection.send(connection, channel, ssh_command.stdin)
    end
    :ssh_connection.send_eof(connection, channel)
    ssh_result =
      if ssh_command.test do
        ResultReader.read_results(connection, channel)
      else
        nil
      end
    :ok = :ssh_connection.close(connection, channel)
    RawCommand.check_sucess(ssh_command, ssh_result)
  end
end
