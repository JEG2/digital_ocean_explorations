defmodule DigitalOcean do
  def images! do
    first_page = DigOc.images!(:distribution)
    do_images!(first_page.images, first_page)
  end

  defp do_images!(images, last_page) do
    if DigOc.Page.next?(last_page) do
      next_page = DigOc.Page.next!(last_page)
      do_images!(images ++ next_page.images, next_page)
    else
      images
    end
  end

  def images_for_distribution!(distribution) do
    images!
    |> Enum.filter(fn image -> image.distribution == distribution end)
  end

  def image_for_distribution_and_version!(distribution, version) do
    images_for_distribution!(distribution)
    |> Enum.find(fn image -> image.name == version end)
  end

  def regions! do
    DigOc.regions!.regions
  end

  def regions_for_image!(image) do
    regions = regions!
    Enum.map(image.regions, fn slug ->
      Enum.find(regions, fn region -> region.slug == slug end)
    end)
  end

  def maximize_features(regions) do
    best_feature_count =
      regions
      |> Enum.map(fn region -> length(region.features) end)
      |> Enum.max
    regions
    |> Enum.filter(fn region ->
      length(region.features) == best_feature_count
    end)
  end

  def favor_region(regions, favorites) do
    Enum.find(regions, hd(regions), fn region ->
      String.contains?(region.name, favorites)
    end)
  end

  def smallest_size(region) do
    hd(region.sizes)
  end

  def create_droplet!(props) do
    DigOc.Droplet.new!(props)
  end

  def delete_droplet!(droplet) do
    DigOc.Droplet.delete!(droplet.id)
  end
end

defmodule Launcher do
  def launch_unless_running(props) do
    DigOc.droplets!.droplets
    |> Enum.find(fn droplet -> droplet.name == props.name end)
    |> do_launch_unless_running(props)
  end

  defp do_launch_unless_running(nil, props) do
    IO.puts "Launching #{props.name}..."
    DigitalOcean.create_droplet!(props)
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
    DigitalOcean.delete_droplet!(running)
    IO.puts "Relaunching #{props.name}..."
    DigitalOcean.create_droplet!(props)
  end
end

image = DigitalOcean.image_for_distribution_and_version!("Debian", "8.5 x64")
region =
  DigitalOcean.regions_for_image!(image)
  |> DigitalOcean.maximize_features
  |> DigitalOcean.favor_region(["New York", "San Fran"])
size = DigitalOcean.smallest_size(region)
props = %{
  name: "elixir-launched",
  image: image.slug,
  region: region.slug,
  size: size
}

Launcher.launch_unless_running(props)
