defmodule ZcashExplorer.Transactions.TransactionWarmer do
  use Cachex.Warmer
  require Logger

  @doc """
  Returns the interval for this warmer.
  """
  def interval,
    do: :timer.seconds(15)

  @doc """
  Executes this cache warmer.
  """
  def execute(_state) do
    recent_block_count = 20
    tx_take = 10

    with {:ok, tip_height} <- Zcashex.getblockcount() do
      txids =
        tip_height..max(tip_height - recent_block_count + 1, 0)
        |> Enum.take(recent_block_count)
        |> Enum.map(fn height ->
          with {:ok, hash} <- ZcashExplorer.RPC.getblockhash(height),
               {:ok, block} <- Zcashex.getblock(hash, 1) do
            Map.get(block, "tx", [])
          else
            _ -> []
          end
        end)
        |> List.flatten()
        |> Enum.take(tx_take)

      txs =
        txids
        |> Enum.map(fn txid ->
          with {:ok, tx} <- Zcashex.getrawtransaction(txid, 1) do
            tx |> Zcashex.Transaction.from_map()
          else
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.map(fn tx ->
          %{
            "txid" => Map.get(tx, :txid),
            "block_height" => Map.get(tx, :height),
            "time" => ZcashExplorerWeb.BlockView.mined_time(Map.get(tx, :time)),
            "tx_out_total" => ZcashExplorerWeb.BlockView.tx_out_total(tx),
            "size" => Map.get(tx, :size),
            "type" => ZcashExplorerWeb.BlockView.tx_type(tx)
          }
        end)

      handle_result(txs)
    else
      {:error, reason} -> handle_result({:error, reason})
    end
  end

  # ignores the warmer result in case of error
  defp handle_result({:error, _reason}) do
    Logger.error("Error while warming the transaction cache.")
    :ignore
  end

  defp handle_result(info) do
    {:ok, [{"transaction_cache", info}]}
  end
end
