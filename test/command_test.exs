defmodule CommandTest do
  use ExUnit.Case, async: true

  alias DigitalOceanExplorations.Command

  test "grouping by distribution and version" do
    grouped = Command.all_by_distribution_and_version
    Enum.each(grouped, fn {{name, distribution, version}, command} ->
      assert is_atom(name)
      assert is_binary(distribution)
      assert is_binary(version)
      assert is_map(command)
      assert command.__struct__ == Command
    end)
  end
end
