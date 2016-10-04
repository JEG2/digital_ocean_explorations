alias DigitalOceanExplorations.{Plan, Deployment, Launcher}
alias DigitalOceanExplorations.Plan.CommandSet
require CommandSet

plan =
  Plan.new(name: "elixir-dsl")
  |> CommandSet.add(:root) do
    install "erlang"
  end
  |> IO.inspect
# deployment = Deployment.new

# droplet = Launcher.launch_unless_running(plan, deployment)
# ip_address = get_in(droplet, [:networks, :v4, Access.at(0), :ip_address])
