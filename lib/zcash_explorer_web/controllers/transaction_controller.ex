defmodule ZcashExplorerWeb.TransactionController do
  use ZcashExplorerWeb, :controller

  def get_transaction(conn, %{"txid" => txid}) do
    case Zcashex.getrawtransaction(txid, 1) do
      {:ok, tx} ->
        tx_data = Zcashex.Transaction.from_map(tx)
        render(conn, "tx.html", tx: tx_data, page_title: "Zcash Transaction #{txid}")

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
end
