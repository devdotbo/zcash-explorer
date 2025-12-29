defmodule ZcashExplorerWeb.AddressController do
  use ZcashExplorerWeb, :controller

  @per_page 20

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
    page = parse_page(params)
    cursor = parse_cursor(params)

    with {:ok, balance, txs, pagination} <- fetch_transparent_address_data(address, page, cursor) do
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
        page: pagination.page,
        total_count: pagination.total_count,
        total_pages: pagination.total_pages,
        has_prev: pagination.has_prev,
        has_next: pagination.has_next,
        next_cursor: pagination.next_cursor,
        page_title: "Zcash Address #{address}"
      )
    else
      {:error, _reason} ->
        conn
        |> put_status(:not_found)
        |> put_view(ZcashExplorerWeb.ErrorView)
        |> render(:invalid_input)
    end
  end

  defp parse_page(%{"page" => page_str}) do
    case Integer.parse(page_str) do
      {n, ""} when n >= 1 -> n
      _ -> 1
    end
  end

  defp parse_page(_), do: 1

  defp parse_cursor(%{"cursor" => cursor_str}) do
    case Integer.parse(cursor_str) do
      {n, ""} when n >= 0 -> n
      _ -> nil
    end
  end

  defp parse_cursor(_), do: nil

  defp fetch_transparent_address_data(address, page, cursor) do
    case Zcashex.getaddressbalance(address) do
      {:ok, balance} ->
        # zcashd supports getaddressdeltas - use legacy mode (no pagination)
        with {:ok, deltas} <- Zcashex.getaddressdeltas(address, 1, 999_999_999, true) do
          all_txs = deltas |> Map.get("deltas", []) |> Enum.reverse()
          paginate_local(balance, all_txs, page)
        else
          {:error, _reason} ->
            # Zebra supports getaddressbalance but not getaddressdeltas
            # Fall back to Zaino for paginated transaction list
            fetch_paginated_from_zaino(address, balance, page, cursor)
        end

      {:error, _reason} ->
        # Neither zcashd nor Zebra balance available - use Zaino for everything
        fetch_all_from_zaino(address, page, cursor)
    end
  end

  defp paginate_local(balance, all_txs, page) do
    total_count = length(all_txs)
    total_pages = max(1, ceil(total_count / @per_page))
    offset = (page - 1) * @per_page
    txs = all_txs |> Enum.drop(offset) |> Enum.take(@per_page)

    pagination = %{
      page: page,
      total_count: total_count,
      total_pages: total_pages,
      has_prev: page > 1,
      has_next: page < total_pages,
      next_cursor: nil
    }

    {:ok, balance, txs, pagination}
  end

  defp fetch_paginated_from_zaino(address, balance, page, cursor) do
    if ZcashExplorer.Lightwalletd.enabled?() do
      opts =
        [max_entries: @per_page, reverse: true]
        |> maybe_add_cursor(cursor)

      case ZcashExplorer.Lightwalletd.taddress_transactions_paginated(address, opts) do
        {:ok, stream} ->
          {txs, total_count, last_height} = process_paginated_stream(stream)

          total_pages = max(1, ceil(total_count / @per_page))
          next_cursor = if last_height && last_height > 0, do: last_height - 1, else: nil

          pagination = %{
            page: page,
            total_count: total_count,
            total_pages: total_pages,
            has_prev: page > 1,
            has_next: page < total_pages && next_cursor != nil,
            next_cursor: next_cursor
          }

          {:ok, balance, txs, pagination}

        {:error, _reason} ->
          # Fallback: return balance with empty transactions
          {:ok, balance, [], empty_pagination(page)}
      end
    else
      {:ok, balance, [], empty_pagination(page)}
    end
  end

  defp fetch_all_from_zaino(address, page, cursor) do
    if ZcashExplorer.Lightwalletd.enabled?() do
      with {:ok, %Cash.Z.Wallet.Sdk.Rpc.Balance{value_zat: balance_zat}} <-
             ZcashExplorer.Lightwalletd.taddress_balance(address) do
        balance = %{"balance" => balance_zat, "received" => nil}
        fetch_paginated_from_zaino(address, balance, page, cursor)
      else
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, :lightwalletd_not_configured}
    end
  end

  defp maybe_add_cursor(opts, nil), do: opts
  defp maybe_add_cursor(opts, cursor), do: Keyword.put(opts, :end_height, cursor)

  defp process_paginated_stream(stream) do
    # Process stream and extract txid directly from Zaino response
    stream
    |> Enum.reduce({[], 0, nil}, fn
      {:ok, %Cash.Z.Wallet.Sdk.Rpc.PaginatedTxidsResponse{} = resp}, {txs, tc, _lh} ->
        new_total = if resp.total_count > 0, do: resp.total_count, else: tc
        # Zaino now includes txid in response (32 bytes, little-endian)
        txid_hex = Base.encode16(resp.txid, case: :lower)
        tx = %{"txid" => txid_hex, "height" => resp.block_height}
        {[tx | txs], new_total, resp.block_height}

      _, acc ->
        acc
    end)
    |> then(fn {txs, total_count, last_height} ->
      {Enum.reverse(txs), total_count, last_height}
    end)
  end

  defp empty_pagination(page) do
    %{
      page: page,
      total_count: 0,
      total_pages: 1,
      has_prev: false,
      has_next: false,
      next_cursor: nil
    }
  end
end
