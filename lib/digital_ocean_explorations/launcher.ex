defmodule DigitalOceanExplorations.Launcher do
  alias DigitalOceanExplorations.{DigitalOceanAPI, DropletStatusHandler}

  def launch_unless_running(props) do
    DigOc.droplets!.droplets
    |> Enum.find(fn droplet -> droplet.name == props.name end)
    |> do_launch_unless_running(props)
  end

  defp do_launch_unless_running(nil, props) do
    IO.puts "Launching #{props.name}..."
    launch_droplet(props)
  end
  defp do_launch_unless_running(
    %{image: %{slug: r_image}, region: %{slug: r_region}, size: %{slug: r_size}},
    props = %{image: p_image, region: p_region, size: p_size}
  )
  when r_image == p_image and r_region == p_region and r_size == p_size do
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