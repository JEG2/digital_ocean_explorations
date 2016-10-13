alias DigitalOceanExplorations.{Plan, Deployment, Launcher, SSH.CommandRunner}
require Plan

user = System.get_env("USER")  # FIXME:  can be nil
ssh_key =
  "./.ssh/id_dsa.pub"
  |> Path.expand(System.user_home!)
  |> File.read!
  |> String.trim

plan =
  Plan.new(name: "elixir-dsl")
  |> Plan.add_commands(:root) do
    add_user user
    add_directory "/home/#{user}/.ssh"
    change_permissions "/home/#{user}/.ssh", "u=rwx,go-rwx"
    add_file "/home/#{user}/.ssh/authorized_keys", ssh_key
    change_permissions "/home/#{user}/.ssh/authorized_keys", "u=rw,go-rwx"
    change_tree_owner "/home/#{user}/.ssh", "#{user}:#{user}"
    insert_after_in_file "/etc/sudoers",
                         "^root\tALL=(ALL:ALL) ALL$",
                         "#{user}\tALL=(ALL) NOPASSWD: ALL"

    replace_in_file "/etc/ssh/sshd_config",
                    "^PermitRootLogin yes$",
                    "PermitRootLogin no"
    replace_in_file "/etc/ssh/sshd_config",
                    "^#PasswordAuthentication yes$",
                    "PasswordAuthentication no"
    insert_before_in_file "/etc/ssh/sshd_config",
                         "^#AuthorizedKeysFile",
                         "PubkeyAcceptedKeyTypes=+ssh-dss"
    restart_service "ssh"
  end
deployment = Deployment.new

droplet = Launcher.launch_unless_running(plan, deployment)
ip_address = get_in(droplet, [:networks, :v4, Access.at(0), :ip_address])

plan
|> Plan.ssh_command_sets
|> Enum.each(fn command_set ->
  CommandRunner.run_commands(ip_address, command_set)
end)
