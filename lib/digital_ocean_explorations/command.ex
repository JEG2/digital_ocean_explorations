defmodule DigitalOceanExplorations.Command do
  defstruct name: nil,
            # distribution => [versions, ...]
            supports: %{ },
            converter: nil

  alias DigitalOceanExplorations.SSH.RawCommand

  def new(details) do
    struct(__MODULE__, details)
  end

  def all_by_distribution_and_version do
    map_commands([
      new(
        name: :add_directory,
        supports: %{"Ubuntu" => ["16.04.1 x64"]},
        converter: fn path ->
          [RawCommand.new("mkdir -p #{path}")]
        end
      ),
      new(
        name: :add_file,
        supports: %{"Ubuntu" => ["16.04.1 x64"]},
        converter: fn path, content ->
          [RawCommand.new("cat - >> #{path}", stdin: content)]
        end
      ),
      new(
        name: :add_user,
        supports: %{"Ubuntu" => ["16.04.1 x64"]},
        converter: fn user_name ->
          [RawCommand.new("useradd -m #{user_name}")]
        end
      ),
      new(
        name: :change_tree_owner,
        supports: %{"Ubuntu" => ["16.04.1 x64"]},
        converter: fn path, owner ->
          [RawCommand.new("chown -R #{owner} #{path}")]
        end
      ),
      new(
        name: :change_permissions,
        supports: %{"Ubuntu" => ["16.04.1 x64"]},
        converter: fn path, permissions ->
          [RawCommand.new("chmod #{permissions} #{path}")]
        end
      ),
      new(
        name: :edit_file,
        supports: %{"Ubuntu" => ["16.04.1 x64"]},
        converter: fn path, pattern, replacement ->
          [ RawCommand.new(
            "sed -i -e 's/#{pattern}/#{replacement}/' #{path}",
            test: :command,
            expected: RawCommand.new("grep '#{grep_escape replacement}' #{path}")
          ) ]
        end
      ),
      new(
        name: :insert_before_in_file,
        supports: %{"Ubuntu" => ["16.04.1 x64"]},
        converter: fn path, pattern, content ->
          [ RawCommand.new(
            "sed -i -e 's/#{pattern}/#{content}\\n&/' #{path}",
            test: :command,
            expected: RawCommand.new("grep '#{grep_escape content}' #{path}")
          ) ]
        end
      ),
      new(
        name: :insert_after_in_file,
        supports: %{"Ubuntu" => ["16.04.1 x64"]},
        converter: fn path, pattern, content ->
          [ RawCommand.new(
            "sed -i -e 's/#{pattern}/&\\n#{content}/' #{path}",
            test: :command,
            expected: RawCommand.new("grep '#{grep_escape content}' #{path}")
          ) ]
        end
      ),
      new(
        name: :replace_in_file,
        supports: %{"Ubuntu" => ["16.04.1 x64"]},
        converter: fn path, pattern, replacement ->
          [ RawCommand.new(
            "sed -i -e 's/#{pattern}/#{replacement}/' #{path}",
            test: :command,
            expected: RawCommand.new("grep '#{grep_escape replacement}' #{path}")
          ) ]
        end
      ),
      new(
        name: :restart_service,
        supports: %{"Ubuntu" => ["16.04.1 x64"]},
        converter: fn service ->
          [RawCommand.new("service #{service} restart")]
        end
      )
    ], %{ })
  end

  # {name, distribution, version} => Command
  defp map_commands([command | commands], mapped_commands) do
    new_mapped_commands =
      map_distributions(command, Map.keys(command.supports), mapped_commands)
    map_commands(commands, new_mapped_commands)
  end
  defp map_commands([ ], mapped_commands), do: mapped_commands

  defp map_distributions(command, [distribution | distributions], mapped) do
    versions = Map.fetch!(command.supports, distribution)
    new_mapped =
      map_versions(command, distribution, versions, mapped)
    map_distributions(command, distributions, new_mapped)
  end
  defp map_distributions(_command, [ ], mapped), do: mapped

  defp map_versions(command, distribution, [version | versions], mapped) do
    new_mapped =
      Map.put(
        mapped,
        {command.name, distribution, version},
        command
      )
    map_versions(command, distribution, versions, new_mapped)
  end
  defp map_versions(_command, _distribution, [ ], mapped), do: mapped

  defp grep_escape(raw_text) do
    raw_text
    # String.replace(raw_text, "+", "\\+")
  end
end
