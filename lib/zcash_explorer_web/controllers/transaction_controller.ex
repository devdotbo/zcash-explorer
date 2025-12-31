defmodule ZcashExplorerWeb.TransactionController do
  use ZcashExplorerWeb, :controller

  def get_transaction(conn, %{"txid" => txid}) do
    case Zcashex.getrawtransaction(txid, 1) do
      {:ok, tx} ->
        tx_data = Zcashex.Transaction.from_map(tx)
        tx_with_enriched_vin = enrich_vin_data(tx_data)
        render(conn, "tx.html", tx: tx_with_enriched_vin, page_title: "Zcash Transaction #{txid}")

      {:error, _reason} ->
        conn
        |> put_status(:not_found)
        |> put_view(ZcashExplorerWeb.ErrorView)
        |> render(:invalid_input)
    end
  end

  def get_raw_transaction(conn, %{"txid" => txid}) do
    case Zcashex.getrawtransaction(txid, 1) do
      {:ok, tx} ->
        data = Poison.encode!(tx, pretty: true)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, data)

      {:error, reason} ->
        error = %{error: "Transaction not found", message: reason}

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(404, Poison.encode!(error))
    end
  end

  # Enrich vin entries with address and value from previous transaction outputs
  defp enrich_vin_data(tx) do
    enriched_vin = Enum.map(tx.vin, fn vin ->
      # Skip coinbase transactions (they have no previous tx to look up)
      if vin.coinbase != nil or vin.txid == nil do
        vin
      else
        case Zcashex.getrawtransaction(vin.txid, 1) do
          {:ok, prev_tx} ->
            prev_tx_data = Zcashex.Transaction.from_map(prev_tx)
            # Get the specific output being spent
            prev_vout = Enum.find(prev_tx_data.vout, fn vout -> vout.n == vin.vout end)

            if prev_vout do
              # Extract address from scriptPubKey.addresses
              address = case prev_vout.scriptPubKey do
                nil -> nil
                spk -> List.first(spk.addresses || [])
              end

              # Update the vin struct with address and value
              %{vin | address: address, value: prev_vout.value}
            else
              vin
            end

          {:error, _} ->
            vin
        end
      end
    end)

    %{tx | vin: enriched_vin}
  end
end
