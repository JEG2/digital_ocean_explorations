defmodule DigitalOceanExplorations.SSH.RawCommand do
  alias DigitalOceanExplorations.SSH.Result

  defstruct command: nil, stdin: nil, test: :exit_status, expected: 0

  def new(command, options \\ [ ]) do
    struct(__MODULE__, [{:command, command} | options])
  end

  def check_sucess(
    %__MODULE__{test: :exit_status, expected: exit_status},
    %Result{exit_status: exit_status}
  ), do: :ok
  def check_sucess(
    %__MODULE__{test: :command, expected: test_command},
    _ssh_result
  ), do: test_command
  def check_sucess(%__MODULE__{test: nil}, nil), do: :ok
  def check_sucess(ssh_command, ssh_result) do
    {:error, ssh_command, ssh_result}
  end
end
