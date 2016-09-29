defmodule PlanTest do
  use ExUnit.Case, async: true

  alias DigitalOceanExplorations.{AbstractCommand, Plan}
  require Plan

  test "empty plans generate an empty list of commands" do
    commands = Plan.commands do
      # empty
    end
    assert commands == [ ]
  end

  test "statements in plans are converted to abstract commands" do
    commands = Plan.commands do
      install "erlang"
    end
    install_command = AbstractCommand.new(name: :install, arguments: ["erlang"])
    assert commands == [install_command]
  end

  test "plans generate a list of commands" do
    commands = Plan.commands do
      install "erlang"
      replace_in_file "/etc/ssh/sshd_config",
                      "PermitRootLogin yes",
                      "PermitRootLogin no",
                      in_place: true
    end
    install_command = AbstractCommand.new(name: :install, arguments: ["erlang"])
    replace_command = AbstractCommand.new(
      name: :replace_in_file,
      arguments: [
        "/etc/ssh/sshd_config",
        "PermitRootLogin yes",
        "PermitRootLogin no",
        [in_place: true]
      ]
    )
    assert commands == [install_command, replace_command]
  end
end
