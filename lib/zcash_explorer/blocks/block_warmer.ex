defmodule ZcashExplorer.Blocks.BlockWarmer do
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

    with {:ok, tip_height} <- Zcashex.getblockcount() do
      start_height = max(tip_height - recent_block_count + 1, 0)

      blocks =
        start_height..tip_height
        |> Task.async_stream(
          fn height ->
            with {:ok, hash} <- ZcashExplorer.RPC.getblockhash(height),
                 {:ok, block} <- Zcashex.getblock(hash, 2) do
              block_struct = Zcashex.Block.from_map(block)

              %{
                "height" => block_struct.height,
                "size" => block_struct.size,
                "hash" => block_struct.hash,
                "time" => ZcashExplorerWeb.BlockView.mined_time(block_struct.time),
                "tx_count" => ZcashExplorerWeb.BlockView.transaction_count(block_struct.tx),
                "output_total" => ZcashExplorerWeb.BlockView.output_total(block_struct.tx)
              }
            else
              _ -> nil
            end
          end,
          max_concurrency: System.schedulers_online() * 2,
          ordered: false,
          timeout: 120_000
        )
        |> Enum.map(fn
          {:ok, v} -> v
          _ -> nil
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.sort(&(&1["height"] >= &2["height"]))

      handle_result(blocks)
    else
      {:error, reason} -> handle_result({:error, reason})
    end
  end

  # ignores the warmer result in case of error
  defp handle_result({:error, _reason}) do
    Logger.error("Error while warming the block cache.")
    :ignore
  end

  defp handle_result(info) do
    {:ok, [{"block_cache", info}]}
  end
end
