defmodule DigitalOceanExplorations.Launcher do
  alias DigitalOceanExplorations.{DigitalOceanAPI, DropletStatusHandler}

  def launch_unless_running(props) do
    DigitalOceanAPI.find_droplet!(props.name)
    |> do_launch_unless_running(props)
  end

  defp do_launch_unless_running(nil, props) do
    IO.puts "Launching #{props.name}..."
    launch_droplet(props)
  end
  defp do_launch_unless_running(
    %{image: %{slug: image}, region: %{slug: region}, size: %{slug: size}},
    props = %{image: image, region: region, size: size}
  ) do
    IO.puts "#{props.name} is already running."
    :ok
  end
  defp do_launch_unless_running(running, props) do
    IO.puts "Shutting down #{props.name}..."
    DigitalOceanAPI.delete_droplet!(running)
    IO.puts "Relaunching #{props.name}..."
    launch_droplet(props)
  end

  defp launch_droplet(props) do
    droplet_id = DigitalOceanAPI.create_droplet!(props).droplet.id
    DropletStatusHandler.wait_for_active_status(droplet_id)
    |> announce_status(props.name)
  end

  defp announce_status(:active, droplet_name) do
    IO.puts "#{droplet_name} is ready."
  end
  defp announce_status(:timeout, droplet_name) do
    IO.puts "#{droplet_name} was never ready."
  end
end
