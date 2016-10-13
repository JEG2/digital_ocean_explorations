defmodule DigitalOceanExplorations.Plan do
  alias DigitalOceanExplorations.AbstractCommand

  defmodule PlanDetails do
    defstruct name: nil,
              distribution: "Ubuntu",
              version: "16.04.1 x64",
              command_sets: [ ]
  end

  defmodule CommandSet do
    defstruct user_name: nil, user_ssh_dir: nil, commands: [ ]

    def new(details) do
      struct(__MODULE__, details)
    end
  end

  def new(details) do
    struct(PlanDetails, details)
  end

  defmacro add_commands(plan, user_name, user_ssh_dir \\ nil, dsl_commands) do
    abstract_commands =
      Macro.prewalk(dsl_commands, [ ], &dsl_to_commands/2)
      |> elem(1)
      |> Enum.reverse
    quote do
      %PlanDetails{
        unquote(plan) |
        command_sets: unquote(plan).command_sets ++ [
          CommandSet.new(
            user_name: unquote(user_name),
            user_ssh_dir: unquote(user_ssh_dir),
            commands: unquote(abstract_commands)
          )
        ]
      }
    end
  end

  defp dsl_to_commands(
    [do: {:__block__, _meta, dsl_commands}],
    abstract_commands
  ) when is_list(dsl_commands) do
    {dsl_commands, abstract_commands}
  end
  defp dsl_to_commands([do: term], abstract_commands) do
    {List.wrap(term), abstract_commands}
  end
  defp dsl_to_commands({name, _meta, arguments}, abstract_commands)
  when is_atom(name) and is_list(arguments) do
    abstract_command =
      quote do
        AbstractCommand.new(name: unquote(name), arguments: unquote(arguments))
      end
    {nil, [abstract_command | abstract_commands]}
  end

  def ssh_command_sets(plan) do
    plan.command_sets
    |> Enum.map(fn command_set ->
      ssh_commands = AbstractCommand.prepare(
        command_set.commands,
        plan.distribution,
        plan.version
      )
      %CommandSet{command_set | commands: ssh_commands}
    end)
  end
end
