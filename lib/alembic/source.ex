defmodule Alembic.Source do
  @moduledoc """
  The `source` of an error.
  """

  alias Alembic.{Document, Error, FromJson}

  # Behaviours

  @behaviour FromJson

  # Struct

  defstruct [:parameter, :pointer]

  # Types

  @typedoc """
  The `ancestor` pointer and the `descendants` of that `ancestor`.
  """
  @type ancestor_descendants :: {ancestor :: Api.json_pointer(), descenants :: [String.t(), ...]}

  @typedoc """
  Options for `ancestor_descendants_from_ecto_changeset_path/2`.
  """
  @type ancestor_descendants_from_ecto_changeset_path_options :: %{
          required(:association_set) => MapSet.t(atom),
          required(:association_by_foreign_key) => %{
            atom => atom
          },
          required(:attribute_set) => MapSet.t(atom),
          required(:format_key) => (atom -> String.t())
        }

  @typedoc """
  A single error field key in the `Ecto.Changeset.t` `:errors` `Keyword.t`
  """
  @type ecto_changeset_error_field :: atom

  @typedoc """
  """
  @type ecto_changeset_path :: [atom() | non_neg_integer(), ...]

  @typedoc """
  Options for `Alembic.Source.pointer_path_from_ecto_changeset_error_field/2`
  """
  @type pointer_path_from_ecto_changeset_error_field_options :: %{
          required(:association_set) => MapSet.t(atom),
          required(:association_by_foreign_key) => %{
            atom => atom
          },
          required(:attribute_set) => MapSet.t(atom),
          required(:format_key) => (atom -> String.t())
        }

  @typedoc """
  A pointer path is composed of the `parent` pointer and the final `child` name.
  """
  @type pointer_path :: {parent :: Api.json_pointer, child :: String.t}

  @typedoc """
  An object containing references to the source of the [error](http://jsonapi.org/format/#error-objects), optionally
  including any of the following members:

  * `pointer` - JSON Pointer ([RFC6901](https://tools.ietf.org/html/rfc6901)) to the associated entity in the request
    document (e.g. `"/data"` for a primary data object, or `"/data/attributes/title"` for a specific attribute).
  * `parameter` - URL query parameter caused the error.
  """
  @type t :: %__MODULE__{
               parameter: String.t,
               pointer: nil
             }
             |
             %__MODULE__{
               parameter: nil,
               pointer: Api.json_pointer
             }

  @doc """
  Converts an `ecto_changeset_path` to a `t:ancestor_descendants/0` that can be used to generate both the
  `Alembic.Source.t` `:pointer` and `Alembic.Error.t` `:detail`

  If `ecto_changeset_path` is in the `association_set`, then the `pointer_path` will be under
  `/data/relationships` and the `descendants` `String.t` will be formatted with `format_key`, so that the expected
  underscore and hypenation rules are followed.

      iex> format_key = fn key ->
      ...>   key |> to_string() |> String.replace("_", "-")
      ...> end
      iex> Alembic.Source.ancestor_descendants_from_ecto_changeset_path(
      ...>   [:favorite_posts],
      ...>   %{
      ...>     association_set: MapSet.new([:designated_editor, :favorite_posts]),
      ...>     association_by_foreign_key: %{designated_editor_id: :designated_editor},
      ...>     attribute_set: MapSet.new([:first_name, :last_name]),
      ...>     format_key: format_key
      ...>   }
      ...> )
      {:ok, {"/data/relationships", ["favorite-posts"]}}

  If `ecto_changeset_path` is a key in `association_by_foreign_key`, then the associated association is used for
  `child` and the parent is `/data/relationships` the same as if the `ecto_cahgneset_error_field` were directly an
  associaton name.

      iex> format_key = fn key ->
      ...>   key |> to_string() |> String.replace("_", "-")
      ...> end
      iex> Alembic.Source.ancestor_descendants_from_ecto_changeset_path(
      ...>   [:designated_editor_id],
      ...>   %{
      ...>     association_set: MapSet.new([:designated_editor, :favorite_posts]),
      ...>     association_by_foreign_key: %{designated_editor_id: :designated_editor},
      ...>     attribute_set: MapSet.new([:first_name, :last_name]),
      ...>     format_key: format_key
      ...>   }
      ...> )
      {:ok, {"/data/relationships", ["designated-editor"]}}

  If `ecto_changeset_path` is in the `attribute_set`, then the `pointer_path` will be under `/data/attributes`
  and the `descendants` `t:String.t/0`s will be formated with `format_key`, so that the expected underscore and hypenation rules
  are followed.

      iex> format_key = fn key ->
      ...>   key |> to_string() |> String.replace("_", "-")
      ...> end
      iex> Alembic.Source.ancestor_descendants_from_ecto_changeset_path(
      ...>   [:first_name],
      ...>   %{
      ...>     association_set: MapSet.new([:designated_editor, :favorite_posts]),
      ...>     association_by_foreign_key: %{designated_editor_id: :designated_editor},
      ...>     attribute_set: MapSet.new([:first_name, :last_name]),
      ...>     format_key: format_key
      ...>   }
      ...> )
      {:ok, {"/data/attributes", ["first-name"]}}

  If `ecto_changeset_path` is not in `association_set`, `attribute_set` or a foreign key in
  `association_by_foreign_key`, then `:error` is returned.  Callers should treat this as indicating the error has no
  source pointer and the `Alembic.Error.t` `:source` should be left `nil`.

      iex> format_key = fn key ->
      ...>   key |> Atom.to_string() |> String.replace("_", "-")
      ...> end
      iex> Alembic.Source.ancestor_descendants_from_ecto_changeset_path(
      ...>   [:name],
      ...>   %{
      ...>     association_set: MapSet.new([:designated_editor, :favorite_posts]),
      ...>     association_by_foreign_key: %{designated_editor_id: :designated_editor},
      ...>     attribute_set: MapSet.new([:first_name, :last_name]),
      ...>     format_key: format_key
      ...>   }
      ...> )
      :error

  Only the `hd(path)` is looked up in `options`: the `tl(path)` is assumed to need no translation, only formatting.

      iex> format_key = fn key ->
      ...>   key |> to_string() |> String.replace("_", "-")
      ...> end
      iex> Alembic.Source.ancestor_descendants_from_ecto_changeset_path(
      ...>   [:primary_authority, :favorite_posts, 0, :primary_authority, :formal_name],
      ...>   %{
      ...>     association_set: MapSet.new(~w(favorite_posts primary_authority)a),
      ...>     association_by_foreign_key: %{primary_authority_id: :primary_authority},
      ...>     attribute_set: MapSet.new(~w(inserted_at text updated_at)a),
      ...>     format_key: format_key
      ...>   }
      ...> )
      {:ok,
       {"/data/relationships",
        ["primary-authority", "favorite-posts", "0", "primary-authority", "formal-name"]}}

  """
  @since "3.5.0"
  @spec ancestor_descendants_from_ecto_changeset_path(
          ecto_changeset_path,
          ancestor_descendants_from_ecto_changeset_path_options
        ) :: {:ok, ancestor_descendants} | :error
  def ancestor_descendants_from_ecto_changeset_path(path = [head | tail], %{
        association_set: association_set,
        association_by_foreign_key: association_by_foreign_key,
        attribute_set: attribute_set,
        format_key: format_key
      }) do
    cond do
      head in attribute_set ->
        {:ok, {"/data/attributes", format_keys(path, format_key)}}

      head in association_set ->
        {:ok, {"/data/relationships", format_keys(path, format_key)}}

      true ->
        case Map.fetch(association_by_foreign_key, head) do
          {:ok, association} ->
            {:ok, {"/data/relationships", format_keys([association | tail], format_key)}}

          :error ->
            :error
        end
    end
  end

  @doc """
  Joins `ancestor` and `descendants` into one `t:Alembic.Api.json_pointer/0`.

      iex> Alembic.Source.ancestor_descendants_to_pointer({"/data/attributes", ["recipients", "0", "name"]})
      "/data/attributes/recipients/0/name"

  """
  @since "3.5.0"
  @spec ancestor_descendants_to_pointer(ancestor_descendants) :: Api.json_pointer()
  def ancestor_descendants_to_pointer({ancestor, descendants}) when is_binary(ancestor) and is_list(descendants) do
    "#{ancestor}/#{Enum.join(descendants, "/")}"
  end

  @doc """
  Descends `pointer` to `child` of current `pointer`

      iex> Alembic.Source.descend(
      ...>   %Alembic.Source{
      ...>     pointer: "/data"
      ...>   },
      ...>   1
      ...> )
      %Alembic.Source{
        pointer: "/data/1"
      }

  """
  @spec descend(t, String.t | integer) :: t
  def descend(source = %__MODULE__{pointer: pointer}, child) do
    %__MODULE__{source | pointer: "#{pointer}/#{child}"}
  end

  @doc """
  Converts a `ancestor_descendants` to a full `t`

      iex> Alembic.Source.from_ancestor_descendants({"/data/attributes", ["recipients", "0", "name"]})
      %Alembic.Source{
        pointer: "/data/attributes/recipients/0/name"
      }

  """
  @since "3.5.0"
  @spec from_ancestor_descendants(ancestor_descendants) :: t()
  def from_ancestor_descendants(ancestor_descendants) do
    %__MODULE__{pointer: ancestor_descendants_to_pointer(ancestor_descendants)}
  end

  @doc """
  Converts JSON object to `t`.

  ## Valid Input

  A parameter can be the source of an error

      iex> Alembic.Source.from_json(
      ...>   %{
      ...>     "parameter" => "q",
      ...>   },
      ...>   %Alembic.Error{
      ...>     source: %Alembic.Source{
      ...>       pointer: "/errors/0/source"
      ...>     }
      ...>   }
      ...> )
      {
        :ok,
        %Alembic.Source{
          parameter: "q"
        }
      }

  A member of a JSON object can be the source of an error, in which case a pointer to the location in the object will
  be given

      iex> Alembic.Source.from_json(
      ...>   %{
      ...>     "pointer" => "/data"
      ...>   },
      ...>   %Alembic.Error{
      ...>     source: %Alembic.Source{
      ...>       pointer: "/errors/0/source"
      ...>     }
      ...>   }
      ...> )
      {
        :ok,
        %Alembic.Source{
          pointer: "/data"
        }
      }

  ## Invalid Input

  It is assumed that only `"parameter"` or `"pointer"` can be set in a single error source (although that's not
  explicit in the JSON API specification), so setting both is an error

      iex> Alembic.Source.from_json(
      ...>   %{
      ...>     "parameter" => "q",
      ...>     "pointer" => "/data"
      ...>   },
      ...>   %Alembic.Error{
      ...>     source: %Alembic.Source{
      ...>       pointer: "/errors/0/source"
      ...>     }
      ...>   }
      ...> )
      {
        :error,
        %Alembic.Document{
          errors: [
            %Alembic.Error{
              detail: "The following members conflict with each other (only one can be present):\\nparameter\\npointer",
              meta: %{
                "children" => [
                  "parameter",
                  "pointer"
                ]
              },
              source: %Alembic.Source{
                pointer: "/errors/0/source"
              },
              status: "422",
              title: "Children conflicting"
            }
          ]
        }
      }

  A parameter **MUST** be a string

      iex> Alembic.Source.from_json(
      ...>   %{
      ...>     "parameter" => true,
      ...>   },
      ...>   %Alembic.Error{
      ...>     source: %Alembic.Source{
      ...>       pointer: "/errors/0/source"
      ...>     }
      ...>   }
      ...> )
      {
        :error,
        %Alembic.Document{
          errors: [
            %Alembic.Error{
              detail: "`/errors/0/source/parameter` type is not string",
              meta: %{
                "type" => "string"
              },
              source: %Alembic.Source{
                pointer: "/errors/0/source/parameter"
              },
              status: "422",
              title: "Type is wrong"
            }
          ]
        }
      }

  A pointer **MUST** be a string

      iex> Alembic.Source.from_json(
      ...>   %{
      ...>     "pointer" => ["data"],
      ...>   },
      ...>   %Alembic.Error{
      ...>     source: %Alembic.Source{
      ...>       pointer: "/errors/0/source"
      ...>     }
      ...>   }
      ...> )
      {
        :error,
        %Alembic.Document{
          errors: [
            %Alembic.Error{
              detail: "`/errors/0/source/pointer` type is not string",
              meta: %{
                "type" => "string"
              },
              source: %Alembic.Source{
                pointer: "/errors/0/source/pointer"
              },
              status: "422",
              title: "Type is wrong"
            }
          ]
        }
      }

  """
  @spec from_json(%{String.t => String.t}, Error.t) :: FromJson.error
  def from_json(json, error_template)

  def from_json(%{"parameter" => _, "pointer" => _}, error_template) do
    {
      :error,
      %Document{
        errors: [
          Error.conflicting(error_template, ~w{parameter pointer})
        ]
      }
    }
  end

  def from_json(%{"parameter" => parameter}, error_template) do
    field_result = parameter
                   |> FromJson.string_from_json(Error.descend(error_template, "parameter"))
                   |> FromJson.put_key(:parameter)

    FromJson.merge({:ok, %__MODULE__{}}, field_result)
  end

  def from_json(%{"pointer" => pointer}, error_template) do
    field_result = pointer
                   |> FromJson.string_from_json(Error.descend(error_template, "pointer"))
                   |> FromJson.put_key(:pointer)

    FromJson.merge({:ok, %__MODULE__{}}, field_result)
  end

  @doc """
  Converts an `ecto_changeset_error_field` to an `Alembic.Source.pointer_path` that can be used to generate both the
  `Alembic.Source.t` `:pointer` and `Alembic.Error.t` `:detail`

  If `ecto_changeset_error_field` is in the `association_set`, then the `pointer_path` will be under
  `/data/relationships` and the `child` `String.t` will be formatted with `format_key`, so that the expected underscore
  and hypenation rules are followed.

      iex> format_key = fn key ->
      ...>   key |> Atom.to_string() |> String.replace("_", "-")
      ...> end
      iex> Alembic.Source.pointer_path_from_ecto_changeset_error_field(
      ...>   :favorite_posts,
      ...>   %{
      ...>     association_set: MapSet.new([:designated_editor, :favorite_posts]),
      ...>     association_by_foreign_key: %{designated_editor_id: :designated_editor},
      ...>     attribute_set: MapSet.new([:first_name, :last_name]),
      ...>     format_key: format_key
      ...>   }
      ...> )
      {:ok, {"/data/relationships", "favorite-posts"}}

  If `ecto_changeset_error_field` is a key in `association_by_foreign_key`, then the associated association is used for
  `child` and the parent is `/data/relationships` the same as if the `ecto_cahgneset_error_field` were directly an
  associaton name.

      iex> format_key = fn key ->
      ...>   key |> Atom.to_string() |> String.replace("_", "-")
      ...> end
      iex> Alembic.Source.pointer_path_from_ecto_changeset_error_field(
      ...>   :designated_editor_id,
      ...>   %{
      ...>     association_set: MapSet.new([:designated_editor, :favorite_posts]),
      ...>     association_by_foreign_key: %{designated_editor_id: :designated_editor},
      ...>     attribute_set: MapSet.new([:first_name, :last_name]),
      ...>     format_key: format_key
      ...>   }
      ...> )
      {:ok, {"/data/relationships", "designated-editor"}}

  If `ecto_changeset_error_field` is in the `attribute_set`, then the `pointer_path` will be under `/data/attributes`
  and the `child` `String.t` will be formated with `format_key`, so that the expected underscore and hypenation rules
  are followed.

      iex> format_key = fn key ->
      ...>   key |> Atom.to_string() |> String.replace("_", "-")
      ...> end
      iex> Alembic.Source.pointer_path_from_ecto_changeset_error_field(
      ...>   :first_name,
      ...>   %{
      ...>     association_set: MapSet.new([:designated_editor, :favorite_posts]),
      ...>     association_by_foreign_key: %{designated_editor_id: :designated_editor},
      ...>     attribute_set: MapSet.new([:first_name, :last_name]),
      ...>     format_key: format_key
      ...>   }
      ...> )
      {:ok, {"/data/attributes", "first-name"}}

  If `ecto_changeset_error_field` is not in `association_set`, `attribute_set` or a foreign key in
  `association_by_foreign_key`, then `:error` is returned.  Callers should treat this as indicating the error has no
  source pointer and the `Alembic.Error.t` `:source` should be left `nil`.

      iex> format_key = fn key ->
      ...>   key |> Atom.to_string() |> String.replace("_", "-")
      ...> end
      iex> Alembic.Source.pointer_path_from_ecto_changeset_error_field(
      ...>   :name,
      ...>   %{
      ...>     association_set: MapSet.new([:designated_editor, :favorite_posts]),
      ...>     association_by_foreign_key: %{designated_editor_id: :designated_editor},
      ...>     attribute_set: MapSet.new([:first_name, :last_name]),
      ...>     format_key: format_key
      ...>   }
      ...> )
      :error

  """
  @deprecated "Use pointer_path_from_ecto_changeset_path/2"
  @spec pointer_path_from_ecto_changeset_error_field(
          ecto_changeset_error_field,
          pointer_path_from_ecto_changeset_error_field_options
        ) :: {:ok, pointer_path} | :error
  def pointer_path_from_ecto_changeset_error_field(
        ecto_changeset_error_field,
        %{
          association_set: association_set,
          association_by_foreign_key: association_by_foreign_key,
          attribute_set: attribute_set,
          format_key: format_key
        }
      ) do
    cond do
      ecto_changeset_error_field in attribute_set ->
        {:ok, {"/data/attributes", format_key.(ecto_changeset_error_field)}}
      ecto_changeset_error_field in association_set ->
        {:ok, {"/data/relationships", format_key.(ecto_changeset_error_field)}}
      true ->
        case Map.fetch(association_by_foreign_key, ecto_changeset_error_field) do
          {:ok, association} ->
            {:ok, {"/data/relationships", format_key.(association)}}
          :error ->
            :error
        end
    end
  end

  @doc false
  @spec ancestor_descendants_from_ecto_changeset_path_options_from_ecto_schema_module(Ecto.Schema.t) ::
          %{
            required(:association_set) => MapSet.t(atom),
            required(:association_by_foreign_key) => %{
              atom => atom
            },
            required(:attribute_set) => MapSet.t(atom)
          }
  def ancestor_descendants_from_ecto_changeset_path_options_from_ecto_schema_module(ecto_schema_module) do
    associations = ecto_schema_module.__schema__(:associations)
    association_by_foreign_key = association_by_foreign_key(associations, ecto_schema_module)
    attributes = ecto_schema_module_to_attributes(
      ecto_schema_module,
      associations ++ Map.keys(association_by_foreign_key)
    )

    %{
      association_set: MapSet.new(associations),
      association_by_foreign_key: association_by_foreign_key,
      attribute_set: MapSet.new(attributes)
    }
  end

  ## Private Functions

  defp association_by_foreign_key(associations, ecto_schema_module) do
    Enum.reduce associations, %{}, fn association, acc ->
      case ecto_schema_module.__schema__(:association, association) do
        %Ecto.Association.BelongsTo{owner_key: foreign_key} ->
          Map.put(acc, foreign_key, association)
        _ ->
          acc
      end
    end
  end

  defp ecto_schema_module_to_attributes(ecto_schema_module, exclusions) do
    # ecto_schema_module.__schema__(:fields) does not include virtual fields, so
    # deduce real and virtual fields from struct keys
    keys = ecto_schema_module.__struct__()
           |> Map.keys()
    keys -- [:__meta__, :__struct__ | exclusions]
  end

  defp format_keys(path, format_key) when is_list(path) and is_function(format_key, 1) do
    Enum.map(path, format_key)
  end

  # Implementations

  defimpl Poison.Encoder do
    alias Alembic.Source

    @doc """
    Encoded `Alembic.Source.t` as a `String.t` contain a JSON object with either a `"parameter"` or `"pointer"` member.
    Whichever field is `nil` in the `Alembic.Source.t` does not appear in the output.

    If `parameter` is set in the `Alembic.Source.t`, then the encoded JSON will only have "parameter"

        iex> Poison.encode(
        ...>   %Alembic.Source{
        ...>     parameter: "q"
        ...>   }
        ...> )
        {:ok, "{\\"parameter\\":\\"q\\"}"}

    If `pointer` is set in the `Alembic.Source.t`, then the encoded JSON will only have "pointer"

        iex> Poison.encode(
        ...>   %Alembic.Source{
        ...>     pointer: "/data"
        ...>   }
        ...> )
        {:ok, "{\\"pointer\\":\\"/data\\"}"}

    """
    # work-around https://github.com/elixir-lang/elixir/issues/4874
    @spec encode(Source.t, Keyword.t) :: String.t

    def encode(%@for{parameter: parameter, pointer: nil}, options) when is_binary(parameter) do
      Poison.Encoder.Map.encode(%{"parameter" => parameter}, options)
    end

    def encode(%@for{parameter: nil, pointer: pointer}, options) when is_binary(pointer) do
      Poison.Encoder.Map.encode(%{"pointer" => pointer}, options)
    end
  end
end
