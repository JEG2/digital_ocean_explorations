defmodule DigitalOceanExplorations.DigitalOceanAPI do
  def keys! do
    DigOc.keys!.ssh_keys
  end

  def find_or_create_key!(name, public_key_loader) do
    key =
      keys!
      |> Enum.find(fn key -> key.name == name end)
    if key do
      key
    else
      DigOc.Key.new!(name, public_key_loader.()).ssh_key
    end
  end

  def find_keys!(names) do
    keys = keys!
    found =
      Enum.map(names, fn name ->
        {name, Enum.find(keys, fn key -> key.name == name end)}
      end)
    missing = Enum.find(found, fn {_name, key} -> is_nil(key) end)
    if missing do
      raise "Key not found:  #{elem(missing, 0)}"
    end
    Enum.map(found, fn {_name, key} -> key end)
  end

  def droplets! do
    DigOc.droplets!.droplets
  end

  def find_droplet!(id) do
    DigOc.droplet!(id).droplet
  end

  def find_droplet_by_name!(name) do
    droplets!
    |> Enum.find(fn droplet -> droplet.name == name end)
  end

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

  def create_droplet!(props) do
    DigOc.Droplet.new!(props)
  end

  def delete_droplet!(droplet) do
    DigOc.Droplet.delete!(droplet.id)
  end
end
