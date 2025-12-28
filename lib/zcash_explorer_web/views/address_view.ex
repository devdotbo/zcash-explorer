defmodule ZcashExplorerWeb.AddressView do
  use ZcashExplorerWeb, :view

  def title(:get_address, _assigns), do: "Edit Profile"

  def zatoshi_to_zec(zatoshi) do
    zatoshi_per_zec = :math.pow(10, -8)
    zatoshi_per_zec * zatoshi
  end

  def spend_zatoshi(received, balance) do
    (received - balance) |> zatoshi_to_zec
  end
end
