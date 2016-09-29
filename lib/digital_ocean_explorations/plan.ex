defmodule DigitalOceanExplorations.Plan do
  alias DigitalOceanExplorations.AbstractCommand

  defmacro commands(dsl_commands) do
    Macro.prewalk(dsl_commands, [ ], &dsl_to_commands/2)
    |> elem(1)
    |> Enum.reverse
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
        %AbstractCommand{name: unquote(name), arguments: unquote(arguments)}
      end
    {nil, [abstract_command | abstract_commands]}
  end
end
