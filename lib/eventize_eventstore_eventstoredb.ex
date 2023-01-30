defmodule Eventize.Eventstore.EventStoreDB do
  @moduledoc """
  A implimentation of the `Eventize.Persistence.EventStore`
  behaviour that uses [EventStoreDB](https://www.eventstore.com/).
  """

  use Eventize.Persistence.EventStore

  alias Eventize.Eventstore.EventStoreDB.EventMapper
  alias Eventize.Eventstore.EventStoreDB.StoredSnapshot

  require Spear.Records.Streams, as: Streams

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{serializer: atom, event_store: atom}

    defstruct serializer: Eventize.Serialization.JasonSerializer,
              event_store: nil
  end

  def start_link(opts) do
    {start_opts, event_store_opts} =
      Keyword.split(opts, [:debug, :name, :timeout, :spawn_opt, :hibernate_after])

    event_store = Keyword.fetch!(event_store_opts, :event_store)

    case Keyword.fetch(event_store_opts, :serializer) do
      {:ok, serializer} ->
        GenServer.start_link(
          __MODULE__,
          %{serializer: serializer, event_store: event_store},
          start_opts
        )

      _ ->
        GenServer.start_link(__MODULE__, %{event_store: event_store}, start_opts)
    end
  end

  def init(%{event_store: event_store, serializer: serializer}) do
    {:ok, %State{serializer: serializer, event_store: event_store}}
  end

  def init(%{event_store: event_store}) do
    {:ok, %State{event_store: event_store}}
  end

  def load_events(
        %{
          stream_name: stream_name,
          start: start,
          max_count: max_count
        },
        _from,
        %State{} = state
      ) do
    case execute_read(state, stream_name, start, max_count) do
      {:ok, events} ->
        version_response =
          case {events, start, max_count} do
            {[], :start, :all} ->
              {:ok, :empty}

            {[], :start, max} when is_integer(max) and max > 0 ->
              {:ok, :empty}

            {e, _, max} when (is_integer(max) and length(e) < max) or max == :all ->
              version =
                e
                |> Enum.map(fn event -> event.sequence_number end)
                |> Enum.max(&>=/2, fn -> :empty end)

              {:ok, version}

            _ ->
              load_heighest_sequence_number(state, stream_name)
          end

        case version_response do
          {:ok, v} ->
            {:reply, {:ok, events, v}, state}

          {:error, err} ->
            {:reply, {:error, err}, state}
        end

      {:error, err} ->
        {:reply, {:error, err}, state}
    end
  end

  def append_events(
        %{stream_name: stream_name, events: events, expected_version: expected_version},
        from,
        %State{} = state
      ) do
    case execute_write(state, expected_version, events, stream_name) do
      {:ok, version} ->
        load_events(
          %{
            stream_name: stream_name,
            start: version - length(events) + 1,
            max_count: :all
          },
          from,
          state
        )

      {:error, err} ->
        {:reply, {:error, err}, state}
    end
  end

  def delete_events(
        %{stream_name: stream_name, version: version},
        _from,
        %State{event_store: event_store} = state
      ) do
    response =
      Spear.set_stream_metadata(event_store, stream_name, %Spear.StreamMetadata{
        truncate_before: version + 1
      })

    {:reply, response, state}
  end

  def load_snapshot(
        %{
          stream_name: stream_name,
          max_version: max_version
        },
        _from,
        %State{} = state
      ) do
    case find_snapshot(state, stream_name, max_version) do
      nil ->
        {:reply, {:ok, nil}, state}

      %StoredSnapshot{} = snapshot ->
        {:reply, {:ok, StoredSnapshot.to_snapshot_data(snapshot)}, state}

      err ->
        {:reply, err, state}
    end
  end

  def append_snapshot(
        %{
          stream_name: stream_name,
          snapshot: {snapshot, meta_data},
          version: version
        },
        from,
        %State{} = state
      ) do
    case execute_write(
           state,
           :any,
           [{snapshot, Map.put(meta_data, :version, version)}],
           get_snapshot_stream(stream_name)
         ) do
      {:ok, _version} ->
        load_snapshot(
          %{
            stream_name: stream_name,
            max_version: version
          },
          from,
          state
        )

      {:error, err} ->
        {:reply, {:error, err}, state}
    end
  end

  def delete_snapshots(
        %{stream_name: stream_name, version: version},
        _from,
        %State{event_store: event_store} = state
      ) do
    case find_snapshot(state, stream_name, version) do
      nil ->
        {:reply, {:ok, nil}, state}

      %StoredSnapshot{sequence_number: sequence_number} ->
        response =
          Spear.set_stream_metadata(
            event_store,
            get_snapshot_stream(stream_name),
            %Spear.StreamMetadata{truncate_before: sequence_number + 1}
          )

        {:reply, response, state}

      err ->
        {:reply, err, state}
    end
  end

  defp get_snapshot_stream(stream_name) do
    "#{stream_name}-snapshots"
  end

  defp load_heighest_sequence_number(
         %State{event_store: event_store, serializer: serializer},
         stream
       ) do
    try do
      last_event =
        Spear.stream!(event_store, stream,
          direction: :backwards,
          from: :end,
          raw?: true,
          chunk_size: 1
        )
        |> Stream.map(fn item -> EventMapper.to_event_data(item, serializer) end)
        |> Enum.at(0)

      case last_event do
        nil ->
          {:ok, :empty}

        %EventData{
          sequence_number: sequence_number
        } ->
          {:ok, sequence_number}
      end
    rescue
      err ->
        {:error, err}
    end
  end

  defp execute_read(
         %State{event_store: event_store, serializer: serializer},
         stream,
         start_version,
         count
       ) do
    try do
      events =
        case count do
          :all ->
            Spear.stream!(event_store, stream, from: start_version, raw?: true)
            |> Stream.map(fn event -> EventMapper.to_event_data(event, serializer) end)
            |> Enum.to_list()

          c ->
            chunk_size =
              case c do
                c when c > 128 ->
                  128

                c ->
                  c
              end

            Spear.stream!(event_store, stream,
              from: start_version,
              raw?: true,
              chunk_size: chunk_size
            )
            |> Stream.take(c)
            |> Stream.map(fn event -> EventMapper.to_event_data(event, serializer) end)
            |> Enum.to_list()
        end

      {:ok, events}
    rescue
      err ->
        {:error, err}
    end
  end

  defp find_snapshot(
         %State{event_store: event_store, serializer: serializer},
         stream,
         max_version
       ) do
    snapshots =
      Spear.stream!(event_store, get_snapshot_stream(stream),
        direction: :backwards,
        from: :end,
        raw?: true,
        chunk_size: 2
      )
      |> Stream.map(fn item -> EventMapper.to_stored_snapshot(item, serializer) end)
      |> Stream.drop_while(fn snapshot ->
        case {max_version, snapshot.version} do
          {:max, _} -> false
          {max, current} when max >= current -> false
          _ -> true
        end
      end)
      |> Enum.take(1)

    case snapshots do
      [] ->
        nil

      [snapshot] ->
        snapshot

      _ ->
        nil
    end
  end

  defp execute_write(
         %State{event_store: event_store, serializer: serializer},
         expected_version,
         events,
         stream_name
       ) do
    spear_events =
      events
      |> Enum.map(fn event -> EventMapper.to_append_message(event, serializer) end)

    opts = [
      expect: expected_version,
      stream: stream_name
    ]

    params = Enum.into(opts, %{})

    messages =
      [Spear.Writing.build_append_request(params)]
      |> Stream.concat(spear_events)
      |> Stream.map(&Spear.Writing.to_append_request/1)

    response =
      Spear.request(
        event_store,
        Streams,
        :Append,
        messages,
        Keyword.take(opts, [:credentials, :timeout])
      )

    case response do
      {:ok,
       Streams.append_resp(
         result:
           {:success,
            Streams.append_resp_success(
              current_revision_option: {:current_revision, current_revision}
            )}
       )} ->
        {:ok, current_revision}

      {:ok, Streams.append_resp(result: {:wrong_expected_version, expectation_violation})} ->
        %Spear.ExpectationViolation{current: current, expected: expected} =
          Spear.Writing.map_expectation_violation(expectation_violation)

        {:error,
         {:expected_version_missmatch, %{current_version: current, expected_version: expected}}}

      error ->
        error
    end
  end
end
