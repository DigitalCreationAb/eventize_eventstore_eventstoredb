defmodule Eventize.Eventstore.EventStoreDB.EventMapper do
  @moduledoc false

  alias Eventize.Persistence.EventStore.EventData
  alias Eventize.Eventstore.EventStoreDB.StoredSnapshot

  def to_event_data(event, serializer) do
    %Spear.Event{
      body: payload,
      type: type,
      metadata: %{
        custom_metadata: meta_data,
        stream_revision: sequence_number
      }
    } =
      Spear.Event.from_read_response(event,
        link?: true,
        json_decoder: fn data, _ ->
          data
        end
      )

    {:ok, deserialized_meta_data} = serializer.deserialize(meta_data)

    body =
      case {type, deserialized_meta_data} do
        {type, %{is_tuple: true}} ->
          {:ok, data} = serializer.deserialize(payload)

          {String.to_atom(type), data}

        {"anon", _} ->
          {:ok, data} = serializer.deserialize(payload)

          data

        {type, _} ->
          {:ok, data} = serializer.deserialize(payload, String.to_atom(type))

          data
      end

    %EventData{
      payload: body,
      meta_data: deserialized_meta_data,
      sequence_number: sequence_number
    }
  end

  def to_stored_snapshot(snapshot, serializer) do
    %Spear.Event{
      body: payload,
      type: type,
      metadata: %{
        custom_metadata: meta_data,
        stream_revision: sequence_number
      }
    } =
      Spear.Event.from_read_response(snapshot,
        link?: true,
        json_decoder: fn data, _ ->
          data
        end
      )

    {:ok, deserialized_meta_data} = serializer.deserialize(meta_data)

    body =
      case {type, deserialized_meta_data} do
        {type, %{is_tuple: true}} ->
          {:ok, data} = serializer.deserialize(payload)

          {String.to_atom(type), data}

        {"anon", _} ->
          {:ok, data} = serializer.deserialize(payload)

          data

        {type, _} ->
          {:ok, data} = serializer.deserialize(payload, String.to_atom(type))

          data
      end

    version =
      case deserialized_meta_data do
        %{version: version} ->
          version

        _ ->
          0
      end

    %StoredSnapshot{
      payload: body,
      meta_data: deserialized_meta_data,
      sequence_number: sequence_number,
      version: version
    }
  end

  def to_append_message({{type, data}, meta_data}, serializer) do
    {:ok, serialized_meta_data} = serializer.serialize(Map.put(meta_data, :is_tuple, true))

    Spear.Event.new(Atom.to_string(type), data, custom_metadata: serialized_meta_data)
    |> Spear.Event.to_proposed_message(%{
      "application/json" => fn data ->
        {:ok, serialized} = serializer.serialize(data)

        serialized
      end
    })
  end

  def to_append_message({data, meta_data}, serializer) when is_struct(data) do
    {:ok, serialized_meta_data} = serializer.serialize(meta_data)

    Spear.Event.new(Atom.to_string(data.__struct__), data, custom_metadata: serialized_meta_data)
    |> Spear.Event.to_proposed_message(%{
      "application/json" => fn data ->
        {:ok, serialized} = serializer.serialize(data)

        serialized
      end
    })
  end

  def to_append_message({data, meta_data}, serializer) do
    {:ok, serialized_meta_data} = serializer.serialize(meta_data)

    Spear.Event.new("anon", data, custom_metadata: serialized_meta_data)
    |> Spear.Event.to_proposed_message(%{
      "application/json" => fn data ->
        {:ok, serialized} = serializer.serialize(data)

        serialized
      end
    })
  end
end
