defmodule ZcashExplorerWeb.AddressController do
  use ZcashExplorerWeb, :controller

  def get_address(conn, %{"address" => address} = params) do
    cond do
      String.starts_with?(address, ["zc", "zs"]) ->
        render_shielded_address(conn, address)

      true ->
        render_transparent_address(conn, address, params)
    end
  end

  def get_ua(conn, %{"address" => ua}) do
    if String.starts_with?(ua, ["u"]) do
      {:ok, details} = Zcashex.z_listunifiedreceivers(ua)
      orchard_present = Map.has_key?(details, "orchard")
      transparent_present = Map.has_key?(details, "p2pkh")
      sapling_present = Map.has_key?(details, "sapling")

      u_qr =
        ua
        |> EQRCode.encode()
        |> EQRCode.png(width: 150, color: <<0, 0, 0>>, background_color: :transparent)
        |> Base.encode64()

      render(conn, "u_address.html",
        address: ua,
        qr: u_qr,
        page_title: "Zcash Unified Address",
        orchard_present: orchard_present,
        transparent_present: transparent_present,
        sapling_present: sapling_present,
        details: details
      )
    else
      conn
      |> put_status(:not_found)
      |> put_view(ZcashExplorerWeb.ErrorView)
      |> render(:invalid_input)
    end
  end

  defp render_shielded_address(conn, address) do
    qr =
      address
      |> EQRCode.encode()
      |> EQRCode.png(width: 150, color: <<0, 0, 0>>, background_color: :transparent)
      |> Base.encode64()

    render(conn, "z_address.html",
      address: address,
      qr: qr,
      page_title: "Zcash Shielded Address"
    )
  end

  defp render_transparent_address(conn, address, params) do
    case Cachex.get(:app_cache, "metrics") do
      {:ok, %{"blocks" => latest_block}} ->
        {start_block, end_block, capped_end_block} = pagination_range(params, latest_block)

        with {:ok, balance, txs} <- fetch_transparent_address_data(address, start_block, capped_end_block) do
          qr =
            address
            |> EQRCode.encode()
            |> EQRCode.png(width: 150, color: <<0, 0, 0>>, background_color: :transparent)
            |> Base.encode64()

          render(conn, "address.html",
            address: address,
            balance: balance,
            txs: txs,
            qr: qr,
            end_block: end_block,
            start_block: start_block,
            latest_block: latest_block,
            capped_e: capped_end_block,
            page_title: "Zcash Address #{address}"
          )
        else
          {:error, _reason} ->
            conn
            |> put_status(:not_found)
            |> put_view(ZcashExplorerWeb.ErrorView)
            |> render(:invalid_input)
        end

      _ ->
        conn
        |> put_status(:service_unavailable)
        |> put_view(ZcashExplorerWeb.ErrorView)
        |> render(:invalid_input)
    end
  end

  defp pagination_range(%{"s" => s, "e" => e}, latest_block) do
    with {:ok, start_block} <- parse_pos_int(s),
         {:ok, end_block} <- parse_pos_int(e) do
      capped_end_block = if end_block > latest_block, do: latest_block, else: end_block
      {start_block, end_block, capped_end_block}
    else
      _ -> default_pagination_range(latest_block)
    end
  end

  defp pagination_range(_params, latest_block), do: default_pagination_range(latest_block)

  defp default_pagination_range(latest_block) do
    chunk_size = 128
    end_block = latest_block
    start_block = ((chunk_size - 1) * (end_block / chunk_size)) |> floor()
    start_block = if start_block <= 0, do: 1, else: start_block
    {start_block, end_block, end_block}
  end

  defp parse_pos_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} when n >= 0 -> {:ok, n}
      _ -> {:error, :invalid_int}
    end
  end

  defp fetch_transparent_address_data(address, start_block, end_block) do
    case Zcashex.getaddressbalance(address) do
      {:ok, balance} ->
        with {:ok, deltas} <- Zcashex.getaddressdeltas(address, start_block, end_block, true) do
          txs = deltas |> Map.get("deltas", []) |> Enum.reverse()
          {:ok, balance, txs}
        end

      {:error, _reason} ->
        fetch_transparent_address_data_from_lightwalletd(address, start_block, end_block)
    end
  end

  defp fetch_transparent_address_data_from_lightwalletd(address, start_block, end_block) do
    if ZcashExplorer.Lightwalletd.enabled?() do
      with {:ok, %Cash.Z.Wallet.Sdk.Rpc.Balance{value_zat: balance_zat}} <-
             ZcashExplorer.Lightwalletd.taddress_balance(address),
           {:ok, stream} <- ZcashExplorer.Lightwalletd.taddress_transactions(address, start_block, end_block) do
        balance = %{"balance" => balance_zat, "received" => nil}

        txs =
          stream
          |> Stream.take(50)
          |> Enum.map(&decode_taddr_tx/1)
          |> Enum.reject(&is_nil/1)
          |> Enum.sort_by(&Map.get(&1, "height"), :desc)

        {:ok, balance, txs}
      else
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, :lightwalletd_not_configured}
    end
  end

  defp decode_taddr_tx(%Cash.Z.Wallet.Sdk.Rpc.RawTransaction{data: data, height: height}) do
    hex = Base.encode16(data, case: :lower)

    case Zcashex.decoderawtransaction(hex) do
      {:ok, %{"txid" => txid}} -> %{"txid" => txid, "height" => height}
      _ -> nil
    end
  end
end
