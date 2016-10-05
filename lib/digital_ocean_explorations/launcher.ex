defmodule DigitalOceanExplorations.Launcher do
  require Logger
  alias DigitalOceanExplorations.{DigitalOceanAPI, DropletStatusHandler}

  def launch_unless_running(plan, deployment) do
    properties = determine_properties(plan, deployment)
    DigitalOceanAPI.find_droplet_by_name!(properties.name)
    |> do_launch_unless_running(properties)
  end

  def determine_properties(plan, deployment) do
    %{
      name: plan.name,
      image: find_image(plan.distribution, plan.version).slug,
      region: deployment.region,
      size: deployment.size,
      ssh_keys: [find_or_create_ssh_key.id]
    }
  end

  defp find_image(distribution, version) do
    DigitalOceanAPI.image_for_distribution_and_version!(
      distribution,
      version
    )
  end

  defp find_or_create_ssh_key do
    DigitalOceanAPI.find_or_create_key!("Elixir Key", fn ->
      "../../priv/ssh/id_rsa.pub"
      |> Path.expand(__DIR__)
      |> File.read!
    end)
  end

  defp do_launch_unless_running(nil, properties) do
    Logger.info "Launching #{properties.name}..."
    launch_droplet(properties)
  end
  defp do_launch_unless_running(
    droplet =
      %{image: %{slug: image}, region: %{slug: region}, size: %{slug: size}},
    properties = %{image: image, region: region, size: size}
  ) do
    Logger.warn "#{properties.name} is already running."
    droplet
  end
  defp do_launch_unless_running(running, properties) do
    Logger.info "Shutting down #{properties.name}..."
    DigitalOceanAPI.delete_droplet!(running)
    Logger.info "Relaunching #{properties.name}..."
    launch_droplet(properties)
  end

  defp launch_droplet(properties) do
    droplet_id = DigitalOceanAPI.create_droplet!(properties).droplet.id
    DropletStatusHandler.wait_for_active_status(droplet_id)
    |> announce_status(properties.name)
    DigitalOceanAPI.find_droplet!(droplet_id)
  end

  defp announce_status(:active, droplet_name) do
    Logger.info "#{droplet_name} is ready."
  end
  defp announce_status(:timeout, droplet_name) do
    Logger.error "#{droplet_name} was never ready."
  end
end
