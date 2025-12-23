defmodule ZcashExplorerWeb.BlockController do
  use ZcashExplorerWeb, :controller

  def get_block(conn, %{"hash" => hash_or_height}) do
    with {:ok, hash, height_hint} <- resolve_block_hash(hash_or_height),
         {:ok, basic_block_data} <- Zcashex.getblock(hash, 1) do
      case length(basic_block_data["tx"]) do
        0 ->
          conn
          |> put_status(:not_found)
          |> put_view(ZcashExplorerWeb.ErrorView)
          |> render(:invalid_input)

        n when n <= 250 ->
          {:ok, block_data} = Zcashex.getblock(hash, 2)
          block_data = Zcashex.Block.from_map(block_data)
          height = block_data.height

          render(conn, "index.html",
            block_data: block_data,
            block_subsidy: nil,
            page_title: "Zcash block #{height}"
          )

        n when n > 250 ->
          title = if is_integer(height_hint), do: "Zcash block #{height_hint}", else: "Zcash block #{hash}"

          render(conn, "basic_block.html",
            block_data: basic_block_data,
            page_title: title
          )
      end
    else
      _ ->
        conn
        |> put_status(:not_found)
        |> put_view(ZcashExplorerWeb.ErrorView)
        |> render(:invalid_input)
    end
  end

  def index(conn, %{"date" => date}) do
    with {:ok, parsed_date} <- Timex.parse(date, "{YYYY}-{0M}-{D}"),
         now <- NaiveDateTime.utc_now() |> Timex.beginning_of_day(),
         diff <- Timex.diff(parsed_date, now, :day),
         true <- diff <= 0,
         {:ok, tip_height} <- Zcashex.getblockcount() do
      previous = Timex.shift(parsed_date, days: -1) |> Timex.format!("{YYYY}-{0M}-{D}")
      next = Timex.shift(parsed_date, days: 1) |> Timex.format!("{YYYY}-{0M}-{D}")
      first_block_date = "2016-10-28"
      disable_previous = first_block_date == date

      disable_next =
        Timex.today()
        |> Timex.format!("{YYYY}-{0M}-{D}")
        |> then(&(&1 == date))

      day_start = parsed_date |> Timex.beginning_of_day() |> Timex.to_unix()
      day_end = parsed_date |> Timex.end_of_day() |> Timex.to_unix()

      start_height = find_first_height_at_or_after(day_start, 0, tip_height)
      end_height = if disable_next, do: tip_height, else: find_last_height_at_or_before(day_end, 0, tip_height)

      blocks_data = fetch_block_headers(start_height, end_height)

      render(conn, "blocks.html",
        blocks_data: blocks_data,
        date: date,
        disable_next: disable_next,
        disable_previous: disable_previous,
        next: next,
        previous: previous,
        page_title: "Zcash blocks mined on #{date}"
      )
    else
      _ ->
        conn
        |> put_status(:not_found)
        |> put_view(ZcashExplorerWeb.ErrorView)
        |> render(:invalid_input)
    end
  end

  def index(conn, _params) do
    today = Timex.today() |> Timex.format!("{YYYY}-{0M}-{D}")
    previous = Timex.today() |> Timex.shift(days: -1) |> Timex.format!("{YYYY}-{0M}-{D}")

    with {:ok, parsed_date} <- Timex.parse(today, "{YYYY}-{0M}-{D}"),
         {:ok, tip_height} <- Zcashex.getblockcount() do
      day_start = parsed_date |> Timex.beginning_of_day() |> Timex.to_unix()
      start_height = find_first_height_at_or_after(day_start, 0, tip_height)
      blocks_data = fetch_block_headers(start_height, tip_height)

      render(conn, "blocks.html",
        blocks_data: blocks_data,
        date: today,
        disable_next: true,
        disable_previous: false,
        previous: previous,
        page_title: "Zcash latest blocks"
      )
    else
      _ ->
        conn
        |> put_status(:service_unavailable)
        |> put_view(ZcashExplorerWeb.ErrorView)
        |> render(:invalid_input)
    end
  end

  defp resolve_block_hash(hash_or_height) when is_binary(hash_or_height) do
    case Integer.parse(hash_or_height) do
      {height, ""} when height >= 0 ->
        with {:ok, hash} <- ZcashExplorer.RPC.getblockhash(height) do
          {:ok, hash, height}
        end

      _ ->
        {:ok, hash_or_height, nil}
    end
  end

  defp fetch_block_headers(start_height, end_height) when start_height > end_height, do: []

  defp fetch_block_headers(start_height, end_height) do
    max_concurrency = System.schedulers_online() * 2

    start_height..end_height
    |> Task.async_stream(
      fn height ->
        with {:ok, hash} <- ZcashExplorer.RPC.getblockhash(height),
             {:ok, header} <- Zcashex.getblockheader(hash) do
          header |> Map.put_new("height", height) |> Map.put_new("hash", hash)
        else
          _ -> nil
        end
      end,
      max_concurrency: max_concurrency,
      ordered: false,
      timeout: 120_000
    )
    |> Enum.map(fn
      {:ok, v} -> v
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(&Map.get(&1, "height"), :desc)
  end

  defp find_first_height_at_or_after(target_time, low, high) do
    case do_find_first_height_at_or_after(target_time, low, high) do
      {:ok, height} -> height
      _ -> high
    end
  end

  defp find_last_height_at_or_before(target_time, low, high) do
    first_after = find_first_height_at_or_after(target_time + 1, low, high)
    max(first_after - 1, 0)
  end

  defp do_find_first_height_at_or_after(target_time, low, high) when low < high do
    mid = div(low + high, 2)

    with {:ok, mid_time} <- block_time(mid) do
      if mid_time < target_time,
        do: do_find_first_height_at_or_after(target_time, mid + 1, high),
        else: do_find_first_height_at_or_after(target_time, low, mid)
    else
      _ -> {:error, :block_time_unavailable}
    end
  end

  defp do_find_first_height_at_or_after(target_time, height, height) do
    with {:ok, time} <- block_time(height) do
      if time >= target_time, do: {:ok, height}, else: {:ok, height + 1}
    else
      _ -> {:error, :block_time_unavailable}
    end
  end

  defp block_time(height) do
    with {:ok, header} <- ZcashExplorer.RPC.getblockheader_by_height(height),
         time when is_integer(time) <- Map.get(header, "time") do
      {:ok, time}
    else
      _ -> {:error, :invalid_block_header}
    end
  end
end
