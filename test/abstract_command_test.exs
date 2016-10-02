defmodule AbstractCommandTest do
  use ExUnit.Case, async: true

  alias DigitalOceanExplorations.{AbstractCommand, SSH.RawCommand}

  test "converts abstract commands to raw SSH commands" do
    abstract_edit_file = AbstractCommand.new(
      name: :edit_file,
      arguments: [
        "/etc/ssh/sshd_config",
        "^#PasswordAuthentication yes$",
        "PasswordAuthentication no"
      ]
    )
    ssh_edit_file = RawCommand.new(
      "sed -i -e 's/^#PasswordAuthentication yes$/" <>
        "PasswordAuthentication no/' /etc/ssh/sshd_config",
      test: :command,
      expected: RawCommand.new(
        "grep 'PasswordAuthentication no' /etc/ssh/sshd_config"
      )
    )
    prepared_commands = AbstractCommand.prepare(
      [abstract_edit_file],
      "Ubuntu",
      "16.04.1 x64"
    )
    assert prepared_commands == [ssh_edit_file]
  end
end
