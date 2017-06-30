defmodule Alembic.ResourceIdentifier do
  @moduledoc """
  A [JSON API Resource Identifier](http://jsonapi.org/format/#document-resource-identifier-objects).
  """

  alias Alembic.{Document, Error, FromJson, Meta, Relationships, Resource, ToParams}

  @behaviour FromJson
  @behaviour ToParams

  # Constants

  @human_type "resource identifier"

  @meta_options %{
    field: :meta,
    member: %{
      module: Meta,
      name: "meta"
    },
    parent: nil
  }

  # Struct

  defstruct [:id, :meta, :type]

  # Types

  @typedoc """
  > A "resource identifier object" is \\[an `%Alembic.ResourceIdentifier{}`\\] that identifies an
  > individual resource.
  >
  > A "resource identifier object" **MUST** contain `type` and `id` members.
  >
  > A "resource identifier object" **MAY** also include a `meta` member, whose value is a
  > \\[`Alembic.Meta.t`\\] that contains non-standard meta-information.
  >
  > -- <cite>
  >  [JSON API - Document Structure - Resource Identifier
  >   Object](http://jsonapi.org/format/#document-resource-identifier-objects)
  > </cite>
  """
  @type t :: %__MODULE__{
               id: String.t,
               meta: Meta.t,
               type: String.t
             }

  # Functions

  @doc """
  # Examples

  ## A resource identifier is valid with `"id"` and `"type"`

      iex> Alembic.ResourceIdentifier.from_json(
      ...>   %{"id" => "1", "type" => "shirt"},
      ...>   %Alembic.Error{
      ...>     source: %Alembic.Source{
      ...>       pointer: "/data/relationships/shirt/data"
      ...>     }
      ...>   }
      ...> )
      {:ok, %Alembic.ResourceIdentifier{id: "1", type: "shirt"}}

  ## A resource identifier can *optionally* have `"meta"`

      iex> Alembic.ResourceIdentifier.from_json(
      ...>   %{"id" => "1", "meta" => %{"copyright" => "2015"}, "type" => "shirt"},
      ...>   %Alembic.Error{
      ...>     source: %Alembic.Source{
      ...>       pointer: "/data/relationships/shirt/data"
      ...>     }
      ...>   }
      ...> )
      {:ok, %Alembic.ResourceIdentifier{id: "1", meta: %{"copyright" => "2015"}, type: "shirt"}}

  ## A resource identifier **MUST** have an `"id"`

      iex> Alembic.ResourceIdentifier.from_json(
      ...>   %{"type" => "shirt"},
      ...>   %Alembic.Error{
      ...>     source: %Alembic.Source{
      ...>       pointer: "/data/relationships/shirt/data"
      ...>     }
      ...>   }
      ...> )
      {
        :error,
        %Alembic.Document{
          errors: [
            %Alembic.Error{
              detail: "`/data/relationships/shirt/data/id` is missing",
              meta: %{
                "child" => "id"
              },
              source: %Alembic.Source{
                pointer: "/data/relationships/shirt/data"
              },
              status: "422",
              title: "Child missing"
            }
          ]
        }
      }

  ## A resource identifer **MUST** have a `"type"`

      iex> Alembic.ResourceIdentifier.from_json(
      ...>   %{"id" => "1"},
      ...>   %Alembic.Error{
      ...>     source: %Alembic.Source{
      ...>       pointer: "/data/relationships/shirt/data"
      ...>     }
      ...>   }
      ...> )
      {
        :error,
        %Alembic.Document{
          errors: [
            %Alembic.Error{
              detail: "`/data/relationships/shirt/data/type` is missing",
              meta: %{
                "child" => "type"
              },
              source: %Alembic.Source{
                pointer: "/data/relationships/shirt/data"
              },
              status: "422",
              title: "Child missing"
            }
          ]
        }
      }

  ## A resource identifer missing both `"id"` and `"type"` will show both as missing

      iex> Alembic.ResourceIdentifier.from_json(
      ...>   %{},
      ...>   %Alembic.Error{
      ...>     source: %Alembic.Source{
      ...>       pointer: "/data/relationships/shirt/data"
      ...>     }
      ...>   }
      ...> )
      {
        :error,
        %Alembic.Document{
          errors: [
            %Alembic.Error{
              detail: "`/data/relationships/shirt/data/id` is missing",
              meta: %{
                "child" => "id"
              },
              source: %Alembic.Source{
                pointer: "/data/relationships/shirt/data"
              },
              status: "422",
              title: "Child missing"
            },
            %Alembic.Error{
              detail: "`/data/relationships/shirt/data/type` is missing",
              meta: %{
                "child" => "type"
              },
              source: %Alembic.Source{
                pointer: "/data/relationships/shirt/data"
              },
              status: "422",
              title: "Child missing"
            }
          ]
        }
      }

  ## A non-resource-identifier will be identified as such

      iex> Alembic.ResourceIdentifier.from_json(
      ...>   [],
      ...>   %Alembic.Error{
      ...>     source: %Alembic.Source{
      ...>       pointer: "/data/relationships/shirt/data"
      ...>     }
      ...>   }
      ...> )
      {
        :error,
        %Alembic.Document{
          errors: [
            %Alembic.Error{
              detail: "`/data/relationships/shirt/data` type is not resource identifier",
              meta: %{
                "type" => "resource identifier"
              },
              source: %Alembic.Source{
                pointer: "/data/relationships/shirt/data"
              },
              status: "422",
              title: "Type is wrong"
            }
          ]
        }
      }

  """
  def from_json(json, error_template)

  @spec from_json(%{String.t => String.t | Alembic.json_object}, Error.t) :: {:ok, t} | FromJson.error
  def from_json(json = %{}, error_template = %Error{}) do
    parent = %{json: json, error_template: error_template}

    id_result = FromJson.from_parent_json_to_field_result %{
      field: :id,
      member: %{
        from_json: &FromJson.string_from_json/2,
        name: "id",
        required: true,
      },
      parent: parent
    }

    meta_result = FromJson.from_parent_json_to_field_result %{@meta_options | parent: parent}

    type_result = FromJson.from_parent_json_to_field_result %{
      field: :type,
      member: %{
        from_json: &FromJson.string_from_json/2,
        name: "type",
        required: true
      },
      parent: parent
    }

    FromJson.reduce([id_result, meta_result, type_result], {:ok, %__MODULE__{}})
  end

  # Alembic.json -- [Alembic.json_object]
  @spec from_json(nil | true | false | list | float | integer | String.t, Error.t) :: FromJson.error
  def from_json(_, error_template) do
    {
      :error,
      %Document{
        errors: [
          Error.type(error_template, @human_type)
        ]
      }
    }
  end

  @doc """
  Converts `resource_identifier` to params format used by
  [`Ecto.Changeset.cast/4`](http://hexdocs.pm/ecto/Ecto.Changeset.html#cast/4).

  `id` and `type` will be used to lookup the attributes in `resource_by_id_by_type`.  Theses attributes and the id
  will be combined into a map for params

      iex> Alembic.ResourceIdentifier.to_params(
      ...>   %Alembic.ResourceIdentifier{id: "1", type: "author"},
      ...>   %{
      ...>     "author" => %{
      ...>       "1" => %Alembic.Resource{
      ...>         type: "author",
      ...>         id: "1",
      ...>         attributes: %{
      ...>           "name" => "Alice"
      ...>         }
      ...>       }
      ...>     }
      ...>   }
      ...> )
      %{
        "id" => "1",
        "name" => "Alice"
      }

  If no entry is found in `resource_by_id_by_type`, then only the `id` is copied to the params.  This can happen when
  the server only wants to send foreign keys.

      iex> Alembic.ResourceIdentifier.to_params(
      ...>   %Alembic.ResourceIdentifier{id: "1", type: "author"},
      ...>   %{}
      ...> )
      %{
        "id" => "1"
      }

  """
  @spec to_params(t, ToParams.resource_by_id_by_type) :: ToParams.params
  def to_params(resource_identifier, resource_by_id_by_type) do
    to_params(resource_identifier, resource_by_id_by_type, %{})
  end

  @spec to_params(t, ToParams.resource_by_id_by_type, ToParams.converted_by_id_by_type) :: ToParams.params
  def to_params(%__MODULE__{id: id, type: type}, resource_by_id_by_type, converted_by_id_by_type) do
    case get_in(resource_by_id_by_type, [type, id]) do
      %Resource{type: ^type, id: ^id, attributes: attributes, relationships: relationships} ->
        case get_in(converted_by_id_by_type, [type, id]) do
          true ->
            %{"id" => id}
          nil ->
            updated_converted_by_id_by_type = converted_by_id_by_type
                                              |> Map.put_new(type, %{})
                                              |> put_in([type, id], true)

            attributes
            |> Map.put("id", id)
            |> Map.merge(
                 Relationships.to_params(relationships, resource_by_id_by_type, updated_converted_by_id_by_type)
               )
        end
      nil ->
        %{"id" => id}
    end
  end

  # Protocol Implementations

  defimpl Poison.Encoder do
    @doc """
    Only non-`nil` members are encoded

        iex> Poison.encode(
        ...>   %Alembic.ResourceIdentifier{
        ...>     type: "post",
        ...>     id: "1"
        ...>   }
        ...> )
        {:ok, "{\\"type\\":\\"post\\",\\"id\\":\\"1\\"}"}

    But, `type` and `id` are always required, so without them, an exception is raised.

        iex> try do
        ...>   Poison.encode(%Alembic.ResourceIdentifier{})
        ...> rescue
        ...>   e in FunctionClauseError -> e
        ...> end
        %FunctionClauseError{
          arity: 2,
          function: :encode,
          module: Poison.Encoder.Alembic.ResourceIdentifier
        }

    """
    def encode(resource_identifier = %@for{type: type, id: id}, options) when not is_nil(type) and not is_nil(id) do
      # strip `nil` so that resource identifiers without meta don't end up with `"meta": null` after encoding
      map = for {field, value} <- Map.from_struct(resource_identifier), value != nil, into: %{}, do: {field, value}

      Poison.Encoder.Map.encode(map, options)
    end
  end
end
