defmodule DigitalOceanExplorations.AbstractCommand do
  defstruct name: nil, arguments: [ ]

  alias DigitalOceanExplorations.Command

  def new(details) do
    struct(__MODULE__, details)
  end

  def prepare(abstract_commands, distribution, version) do
    commands = Command.all_by_distribution_and_version
    Enum.flat_map(abstract_commands, fn abstract_command ->
      command =
        Map.fetch!(commands, {abstract_command.name, distribution, version})
      apply(command.converter, abstract_command.arguments)
    end)
  end
end
