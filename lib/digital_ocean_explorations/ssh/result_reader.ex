defmodule DigitalOceanExplorations.SSH.ResultReader do
  require Logger
  alias DigitalOceanExplorations.SSH.Result

  @stdout 0
  @stderr 1

  def read_results(connection, channel) do
    read_results(connection, channel, %Result{ })
  end

  defp read_results(
    connection,
    channel,
    result = %Result{stdout: stdout, stderr: stderr}
  ) do
    receive do
      {:ssh_cm, ^connection, {:data, ^channel, @stdout, data}} ->
        Logger.debug("STDOUT:  #{inspect(data)}")
        new_result = %Result{result | stdout: stdout <> data}
        read_results(connection, channel, new_result)
      {:ssh_cm, ^connection, {:data, ^channel, @stderr, data}} ->
        Logger.debug("STDERR:  #{inspect(data)}")
        new_result = %Result{result | stderr: stderr <> data}
        read_results(connection, channel, new_result)
      {:ssh_cm, ^connection, {:eof, ^channel}} ->
        read_results(connection, channel, result)
      {:ssh_cm, ^connection, {:exit_status, ^channel, exit_status}} ->
        Logger.debug("EXIT_STATUS:  #{exit_status}")
        new_result = %Result{result | exit_status: exit_status}
        read_results(connection, channel, new_result)
      {:ssh_cm, ^connection, {:closed, ^channel}} ->
        result
    end
  end
end
