alias DigitalOceanExplorations.{Plan, Deployment, Launcher}
require Plan

user = System.get_env("USER")  # FIXME:  can be nil
ssh_keys =
  [
    "../priv/ssh/id_rsa.pub" |> Path.expand(__DIR__) |> File.read!,
    "./.ssh/id_dsa.pub" |> Path.expand(System.user_home!) |> File.read!
  ]
  |> Enum.map(&String.trim/1)
  |> Enum.join("\n")

plan =
  Plan.new(name: "elixir-dsl")
  |> Plan.add_commands(:root) do
    add_user user
    add_path "/home/#{user}/.ssh",
             permissions: "u=rwx,go-rwx"
    add_file "/home/#{user}/.ssh/authorized_keys",
             permissions: "u=rw,go-rwx",
             contents: ssh_keys
    change_owner "/home/#{user}/.ssh",
                 recursive: true
    insert_in_file "/etc/sudoers",
                   "#{user}\\tALL=(ALL) NOPASSWD: ALL",
                   after: "^root\\tALL=(ALL:ALL) ALL$"
  end
  |> IO.inspect
# deployment = Deployment.new

# droplet = Launcher.launch_unless_running(plan, deployment)
# ip_address = get_in(droplet, [:networks, :v4, Access.at(0), :ip_address])
