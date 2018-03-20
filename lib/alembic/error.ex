defmodule Alembic.Error do
  @moduledoc """
  [Error objects](http://jsonapi.org/format/#error-objects) provide additional information about problems encountered
  while performing an operation. Error objects **MUST** be returned as an array keyed by `errors` in the top level of a
  JSON API document.
  """

  alias Alembic.{FromJson, Links, Meta, Source}

  # Behaviours

  @behaviour FromJson

  # Constants

  @code_options %{
    field: :code,
    member: %{
      from_json: &FromJson.string_from_json/2,
      name: "code"
    },
  }

  @detail_options %{
    field: :detail,
    member: %{
      from_json: &FromJson.string_from_json/2,
      name: "detail"
    },
  }

  @id_options %{
    field: :id,
    member: %{
      from_json: &FromJson.string_from_json/2,
      name: "id"
    }
  }

  @links_options %{
    field: :links,
    member: %{
      module: Links,
      name: "links"
    }
  }

  @meta_options %{
    field: :meta,
    member: %{
      module: Meta,
      name: "meta"
    }
  }

  @source_options %{
    field: :source,
    member: %{
      module: Source,
      name: "source"
    }
  }

  @status_options %{
    field: :status,
    member: %{
      from_json: &FromJson.string_from_json/2,
      name: "status"
    }
  }

  @title_options %{
    field: :title,
    member: %{
      from_json: &FromJson.string_from_json/2,
      name: "title"
    }
  }

  @child_options_list [
    @code_options,
    @detail_options,
    @id_options,
    @links_options,
    @meta_options,
    @source_options,
    @status_options,
    @title_options
  ]

  # Struct

  defstruct code: nil,
            detail: nil,
            id: nil,
            links: nil,
            meta: nil,
            source: nil,
            status: nil,
            title: nil

  # Types

  @typedoc """
  A single error field key in the `Ecto.Changeset.t` `:errors` `Keyword.t`
  """
  @type ecto_changeset_error_field :: atom

  @typedoc """
  A single error message value in the `Ecto.Changeset.t` `:errors` `Keyword.t`.
  """
  @type ecto_changeset_error_message :: {format :: String.t, value_by_key :: Keyword.t}

  @typedoc """
  A single error in `Ecto.Changeset.t` `:errors` `Keyword.t`
  """
  @type ecto_changeset_error :: {ecto_changeset_error_field :: atom, ecto_changeset_error_message}

  @typedoc """
  The name of a JSON type in human-readable terms, such as `"array"` or `"object"`.
  """
  @type human_type :: String.t

  @typedoc """
  Additional information about problems encountered while performing an operation.

  An error object **MAY** have the following members:

  * `code` - an application-specific error code.
  * `detail` - a human-readable explanation specific to this occurrence of the problem.
  * `id` - a unique identifier for this particular occurrence of the problem.
  * `links` - contains the following members:
      * `"about"` - an `Alembic.Link.link` leading to further details about this particular occurrence of the problem.
  * `meta` - non-standard meta-information about the error.
  * `source` - contains references to the source of the error, optionally including any of the following members:
  * `status` - the HTTP status code applicable to this problem.
  * `title` - a short, human-readable summary of the problem that **SHOULD NOT** change from occurrence to occurrence of
    the problem, except for purposes of localization.
  """
  @type t :: %__MODULE__{
               code: String.t | nil,
               detail: String.t | nil,
               id: String.t | nil,
               links: Links.t | nil,
               meta: %{String.t => Alembic.json | atom} | nil,
               source: Source.t | nil,
               status: String.t | nil,
               title: String.t | nil
             }

  @doc """
  Descends `source` `pointer` to `child` of current `source` `pointer`

      iex> Alembic.Error.descend(
      ...>   %Alembic.Error{
      ...>     source: %Alembic.Source{
      ...>       pointer: "/data"
      ...>     }
      ...>   },
      ...>   1
      ...> )
      %Alembic.Error{
        source: %Alembic.Source{
          pointer: "/data/1"
        }
      }

  """
  @spec descend(t, String.t | integer) :: t
  def descend(error = %__MODULE__{source: source}, child) do
    %__MODULE__{error | source: Source.descend(source, child)}
  end

  @doc """
  Converts an `Ecto.Changeset.t` error composed of the `field` the error occurred on and the error `message`

  The `field` is converted an `Alembic.Source.t` `:pointer`.  If it cannot be converted, then the returned `t` will have
  not `:source`.  The child part of the `:pointer` is formatted with `:format_key`.

  If `field` is in `association_set` in `pointer_path_from_ecto_changeset_error_field_options`, then the `pointer` will
  be under `/data/relationships`.

      iex> format_key = fn key ->
      ...>   key |> Atom.to_string() |> String.replace("_", "-")
      ...> end
      iex> Alembic.Error.from_ecto_changeset_error(
      ...>   {:favorite_posts, {"are still associated with this entry", []}},
      ...>   %{
      ...>     association_set: MapSet.new([:designated_editor, :favorite_posts]),
      ...>     association_by_foreign_key: %{designated_editor_id: :designated_editor},
      ...>     attribute_set: MapSet.new([:first_name, :last_name]),
      ...>     format_key: format_key
      ...>   }
      ...> )
      %Alembic.Error{
        detail: "favorite-posts are still associated with this entry",
        source: %Alembic.Source{
          pointer: "/data/relationships/favorite-posts"
        },
        title: "are still associated with this entry"
      }

  If `field` is a key in `association_by_foreign_key` in `pointer_path_from_ecto_changeset_error_field_options`, then
  the `pointer` will be under `/data/relationships`, but the child will be the name of the (formatted) association
  instead of the foreign key field itself as JSONAPI attributes should not contain foreign keys.

      iex> format_key = fn key ->
      ...>   key |> Atom.to_string() |> String.replace("_", "-")
      ...> end
      iex> Alembic.Error.from_ecto_changeset_error(
      ...>   {:designated_editor_id, {"can't be blank", [validation: :required]}},
      ...>   %{
      ...>     association_set: MapSet.new([:designated_editor, :favorite_posts]),
      ...>     association_by_foreign_key: %{designated_editor_id: :designated_editor},
      ...>     attribute_set: MapSet.new([:first_name, :last_name]),
      ...>     format_key: format_key
      ...>   }
      ...> )
      %Alembic.Error{
        detail: "designated-editor can't be blank",
        source: %Alembic.Source{
          pointer: "/data/relationships/designated-editor"
        },
        title: "can't be blank"
      }

  If `field` is in `attribute_set` in `pointer_path_from_ecto_changeset_error_field_options`, then the `pointer` will be
  under `/data/attributes`.

      iex> format_key = fn key ->
      ...>   key |> Atom.to_string() |> String.replace("_", "-")
      ...> end
      iex> Alembic.Error.from_ecto_changeset_error(
      ...>   {:first_name, {"should be at least %{count} character(s)", [count: 2, validation: :length, min: 2]}},
      ...>   %{
      ...>     association_set: MapSet.new([:designated_editor, :favorite_posts]),
      ...>     association_by_foreign_key: %{designated_editor_id: :designated_editor},
      ...>     attribute_set: MapSet.new([:first_name, :last_name]),
      ...>     format_key: format_key
      ...>   }
      ...> )
      %Alembic.Error{
        detail: "first-name should be at least 2 character(s)",
        source: %Alembic.Source{
          pointer: "/data/attributes/first-name"
        },
        title: "should be at least 2 character(s)"
      }

  If `field` is not in `association_set`, `attribute_set`, or a foreign key in `association_by_foreign_key` in
  `pointer_path_from_ecto_changeset_error_field_options`, then the `t` `:source` will be `nil`

      iex> format_key = fn key ->
      ...>   key |> Atom.to_string() |> String.replace("_", "-")
      ...> end
      iex> Alembic.Error.from_ecto_changeset_error(
      ...>   {:favorite_flavor, {"is not allowed", []}},
      ...>   %{
      ...>     association_set: MapSet.new([:designated_editor, :favorite_posts]),
      ...>     association_by_foreign_key: %{designated_editor_id: :designated_editor},
      ...>     attribute_set: MapSet.new([:first_name, :last_name]),
      ...>     format_key: format_key
      ...>   }
      ...> )
      %Alembic.Error{
        detail: "favorite-flavor is not allowed",
        title: "is not allowed"
      }

  """
  @deprecated "Use from_ecto_changeset_path/2 instead as it handles deeply nested paths for object attributes and " <>
                "embeds"
  @spec from_ecto_changeset_error(ecto_changeset_error, Source.pointer_path_from_ecto_changeset_error_field_options) ::
          Error.t
  def from_ecto_changeset_error(
        {field, message},
        pointer_path_from_ecto_changeset_error_field_options = %{format_key: format_key}
      ) do
    title = title_from_ecto_changeset_error_message(message)

    field
    |> Source.pointer_path_from_ecto_changeset_error_field(pointer_path_from_ecto_changeset_error_field_options)
    |> case do
         {:ok, {parent, child}} ->
           %__MODULE__{
             detail: "#{child} #{title}",
             source: %Source{
               pointer: "#{parent}/#{child}"
             },
             title: title
           }

         :error ->
           %__MODULE__{
             detail: "#{format_key.(field)} #{title}",
             title: title
           }
       end
  end

  @doc """
  Converts an `Ecto.Changeset.t` error composed of the `path` the error occurred on and the error `message`.  `path`
  is a list of fields and indexes to get to the error.

  The `path` is converted an `t:Alembic.Source.t/0` `:pointer`.  If it cannot be converted, then the returned `t` will
  have not `:source`.  The descendants part of the `:pointer` is formatted with `:format_key`.

  If `hd(path)` is in `association_set` in `options`, then the `pointer` will be under `/data/relationships`.

      iex> format_key = fn key ->
      ...>   key |> to_string() |> String.replace("_", "-")
      ...> end
      iex> Alembic.Error.from_ecto_changeset_path(
      ...>   [:favorite_posts],
      ...>   %{
      ...>     association_set: MapSet.new([:designated_editor, :favorite_posts]),
      ...>     association_by_foreign_key: %{designated_editor_id: :designated_editor},
      ...>     attribute_set: MapSet.new([:first_name, :last_name]),
      ...>     format_key: format_key
      ...>   }
      ...> )
      %Alembic.Error{
        detail: "favorite-posts",
        source: %Alembic.Source{
          pointer: "/data/relationships/favorite-posts"
        }
      }

  If `hd(path)` is a key in `association_by_foreign_key` in `options`, then the `pointer` will be under
  `/data/relationships`, but the child will be the name of the (formatted) association instead of the foreign key field
  itself as JSONAPI attributes should not contain foreign keys.

      iex> format_key = fn key ->
      ...>   key |> to_string() |> String.replace("_", "-")
      ...> end
      iex> Alembic.Error.from_ecto_changeset_path(
      ...>   [:designated_editor_id],
      ...>   %{
      ...>     association_set: MapSet.new([:designated_editor, :favorite_posts]),
      ...>     association_by_foreign_key: %{designated_editor_id: :designated_editor},
      ...>     attribute_set: MapSet.new([:first_name, :last_name]),
      ...>     format_key: format_key
      ...>   }
      ...> )
      %Alembic.Error{
        detail: "designated-editor",
        source: %Alembic.Source{
          pointer: "/data/relationships/designated-editor"
        }
      }

  If `hd(path)` is in `attribute_set` in `options`, then the `pointer` will be under `/data/attributes`.

      iex> format_key = fn key ->
      ...>   key |> to_string() |> String.replace("_", "-")
      ...> end
      iex> Alembic.Error.from_ecto_changeset_path(
      ...>   [:first_name],
      ...>   %{
      ...>     association_set: MapSet.new([:designated_editor, :favorite_posts]),
      ...>     association_by_foreign_key: %{designated_editor_id: :designated_editor},
      ...>     attribute_set: MapSet.new([:first_name, :last_name]),
      ...>     format_key: format_key
      ...>   }
      ...> )
      %Alembic.Error{
        detail: "first-name",
        source: %Alembic.Source{
          pointer: "/data/attributes/first-name"
        }
      }

  If `hd(path)` is not in `association_set`, `attribute_set`, or a foreign key in `association_by_foreign_key` in
  `options`, then the `t` `:source` will be `nil`

      iex> format_key = fn key ->
      ...>   key |> to_string() |> String.replace("_", "-")
      ...> end
      iex> Alembic.Error.from_ecto_changeset_path(
      ...>   [:favorite_flavor],
      ...>   %{
      ...>     association_set: MapSet.new([:designated_editor, :favorite_posts]),
      ...>     association_by_foreign_key: %{designated_editor_id: :designated_editor},
      ...>     attribute_set: MapSet.new([:first_name, :last_name]),
      ...>     format_key: format_key
      ...>   }
      ...> )
      %Alembic.Error{
        detail: "favorite_flavor"
      }

  Only the `hd(path)` is looked up in `options`: the `tl(path)` is assumed to need no translation, only formatting.

      iex> format_key = fn key ->
      ...>   key |> to_string() |> String.replace("_", "-")
      ...> end
      iex> Alembic.Error.from_ecto_changeset_path(
      ...>   [:author, :posts, 0, :author, :name],
      ...>   %{
      ...>     association_set: MapSet.new(~w(author comments tags)a),
      ...>     association_by_foreign_key: %{author_id: :author},
      ...>     attribute_set: MapSet.new(~w(inserted_at text updated_at)a),
      ...>     format_key: format_key
      ...>   }
      ...> )
      %Alembic.Error{
        detail: "author posts 0 author name",
        source: %Alembic.Source{
          pointer: "/data/relationships/author/posts/0/author/name"
        }
      }

  """
  @since "3.5.0"
  def from_ecto_changeset_path(path, options) when is_list(path) and is_map(options) do
    path
    |> Source.ancestor_descendants_from_ecto_changeset_path(options)
    |> case do
      {:ok, ancestor_descendants = {_, descendants}} ->
        %__MODULE__{
          detail: path_to_detail(descendants),
          source: Source.from_ancestor_descendants(ancestor_descendants)
        }

      :error ->
        %__MODULE__{
          detail: path_to_detail(path)
        }
    end
  end

  @doc """
  Converts a JSON object into a JSON API Error, `t`.

      iex> Alembic.Error.from_json(
      ...>   %{
      ...>     "code" => "1",
      ...>     "detail" => "There was an error in data",
      ...>     "id" => "2",
      ...>     "links" => %{
      ...>       "about" => %{
      ...>         "href" => "/errors/2",
      ...>         "meta" => %{
      ...>           "extra" => "about meta"
      ...>         }
      ...>       }
      ...>     },
      ...>     "meta" => %{
      ...>       "extra" => "error meta"
      ...>     },
      ...>     "source" => %{
      ...>       "pointer" => "/data"
      ...>     },
      ...>     "status" => "422",
      ...>     "title" => "There was an error"
      ...>   },
      ...>   %Alembic.Error{
      ...>     source: %Alembic.Source{
      ...>       pointer: "/errors/0"
      ...>     }
      ...>   }
      ...> )
      {
        :ok,
        %Alembic.Error{
          code: "1",
          detail: "There was an error in data",
          id: "2",
          links: %{
            "about" => %Alembic.Link{
              href: "/errors/2",
              meta: %{
                "extra" => "about meta"
              }
            }
          },
          meta: %{
            "extra" => "error meta"
          },
          source: %Alembic.Source{
            pointer: "/data"
          },
          status: "422",
          title: "There was an error"
        }
      }

  """
  def from_json(json_object = %{}, template = %__MODULE__{}) do
    parent = %{json: json_object, error_template: template}

    @child_options_list
    |> Stream.map(&Map.put(&1, :parent, parent))
    |> Stream.map(&FromJson.from_parent_json_to_field_result/1)
    |> FromJson.reduce({:ok, %__MODULE__{}})
  end

  @doc """
  When two or more members can't be present at the same time.

      iex> Alembic.Error.conflicting(
      ...>   %Alembic.Error{
      ...>     source: %Alembic.Source{
      ...>       pointer: "/errors/0/source"
      ...>     }
      ...>   },
      ...>   ~w{parameter pointer}
      ...> )
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

  """
  @spec conflicting(t, [String.t]) :: t
  def conflicting(template, children)

  def conflicting(%__MODULE__{source: source}, children) when is_list(children) do
    %__MODULE__{
      detail: "The following members conflict with each other (only one can be present):\n" <>
              Enum.join(children, "\n"),
      meta: %{
        "children" => children
      },
      source: source,
      status: "422",
      title: "Children conflicting"
    }
  end

  @doc """
  When the minimum number of children are not present, give the sender a list of the children they could have sent.

      iex> Alembic.Error.minimum_children(
      ...>   %Alembic.Error{
      ...>     source: %Alembic.Source{
      ...>       pointer: "/data/relationships/author"
      ...>     }
      ...>   },
      ...>   ~w{data links meta}
      ...> )
      %Alembic.Error{
        detail: "At least one of the following children of `/data/relationships/author` must be present:\\n" <>
                "data\\n" <>
                "links\\n" <>
                "meta",
        meta: %{
          "children" => [
            "data",
            "links",
            "meta"
          ]
        },
        source: %Alembic.Source{
          pointer: "/data/relationships/author"
        },
        status: "422",
        title: "Not enough children"
      }

  """
  @spec minimum_children(t, [String.t]) :: t
  def minimum_children(template, children)

  def minimum_children(
        %__MODULE__{source: source = %Source{pointer: parent_pointer}},
        children
      ) when is_list(children) do
    %__MODULE__{
      detail: "At least one of the following children of `#{parent_pointer}` must be present:\n" <>
              Enum.join(children, "\n"),
      meta: %{
        "children" => children
      },
      source: source,
      status: "422",
      title: "Not enough children"
    }
  end

  @doc """
  When a required (**MUST** in the spec) member is missing

  # Top-level member is missing

      iex> Alembic.Error.missing(
      ...>   %Alembic.Error{
      ...>     source: %Alembic.Source{
      ...>       pointer: ""
      ...>     }
      ...>   },
      ...>   "data"
      ...> )
      %Alembic.Error{
        detail: "`/data` is missing",
        meta: %{
          "child" => "data"
        },
        source: %Alembic.Source{
          pointer: ""
        },
        status: "422",
        title: "Child missing"
      }

  # Nested member is missing

      iex> Alembic.Error.missing(
      ...>   %Alembic.Error{
      ...>     source: %Alembic.Source{
      ...>       pointer: "/data"
      ...>     }
      ...>   },
      ...>   "type"
      ...> )
      %Alembic.Error{
        detail: "`/data/type` is missing",
        meta: %{
          "child" => "type"
        },
        source: %Alembic.Source{
          pointer: "/data"
        },
        status: "422",
        title: "Child missing"
      }

  """
  @spec missing(t, String.t) :: t
  def missing(template, child)

  def missing(%__MODULE__{source: source = %Source{pointer: parent_pointer}}, child) do
    %__MODULE__{
      detail: "`#{parent_pointer}/#{child}` is missing",
      meta: %{
        "child" => child
      },
      source: source,
      status: "422",
      title: "Child missing"
    }
  end

  @doc """
  When a relationship path in `"includes"` params is unknown.

  If no template is given, it is assumed that the source is the "include" parameter

      iex> Alembic.Error.relationship_path("secret")
      %Alembic.Error{
        detail: "`secret` is an unknown relationship path",
        meta: %{
          "relationship_path" => "secret"
        },
        source: %Alembic.Source{
          parameter: "include"
        },
        title: "Unknown relationship path"
      }

  If using a different parameter than recommended in the JSON API spec, a template can be used

      iex> Alembic.Error.relationship_path(
      ...>   %Alembic.Error{
      ...>     source: %Alembic.Source{
      ...>       parameter: "relationships"
      ...>     }
      ...>   },
      ...>   "secret"
      ...> )
      %Alembic.Error{
        detail: "`secret` is an unknown relationship path",
        meta: %{
          "relationship_path" => "secret"
        },
        source: %Alembic.Source{
          parameter: "relationships"
        },
        title: "Unknown relationship path"
      }

  """
  @spec relationship_path(String.t) :: t
  @spec relationship_path(t, String.t) :: t
  def relationship_path(
        template \\ %__MODULE__{
          source: %Source{
            parameter: "include"
          }
        },
        unknown_relationship_path
      )
  def relationship_path(%__MODULE__{source: source}, unknown_relationship_path) do
    %__MODULE__{
      detail: "`#{unknown_relationship_path}` is an unknown relationship path",
      meta: %{
        "relationship_path" => unknown_relationship_path
      },
      source: source,
      title: "Unknown relationship path"
    }
  end

  @doc """
  Fills in the `format` of the error message using the values for the format keys in `value_by_key`
  """
  @spec title_from_ecto_changeset_error_message(ecto_changeset_error_message) :: String.t
  def title_from_ecto_changeset_error_message({format, value_by_key}) do
    # See https://github.com/elixir-ecto/ecto/blob/34a1012dd1f6d218c0183deb512b6c084afe3b6f/
    #     lib/ecto/changeset.ex#L1836-L1838
    Enum.reduce value_by_key, format, fn {key, value}, acc ->
      case key do
        :type -> acc
        _ -> String.replace(acc, "%{#{key}}", to_string(value))
      end
    end
  end

  @doc """
  Error when the JSON type of the field is wrong.

  **NOTE: The *JSON* type should be used, not the Elixir/Erlang type, so if a member is not a `map` in Elixir, the
  `human_type` should be `"object"`.  Likewise, if a member is not a `list` in Elixir, the `human_type` should be
  `"array"`.**

  # When member is not an Elixir `list` or JSON array

      iex> validate_errors = fn
      ...>   (list) when is_list(list) ->
      ...>     {:ok, list}
      ...>   (_) ->
      ...>     {
      ...>       :error,
      ...>       Alembic.Error.type(
      ...>         %Alembic.Error{
      ...>           source: %Alembic.Source{
      ...>             pointer: "/errors"
      ...>           }
      ...>         },
      ...>         "array"
      ...>       )
      ...>     }
      ...> end
      iex> json = %{"errors" => "invalid"}
      iex> validate_errors.(json["errors"])
      {
        :error,
        %Alembic.Error{
          detail: "`/errors` type is not array",
          meta: %{
            "type" => "array"
          },
          source: %Alembic.Source{
            pointer: "/errors"
          },
          status: "422",
          title: "Type is wrong"
        }
      }

  # When member is not an Elixir `map` or JSON object

      iex> validate_meta = fn
      ...>   (meta) when is_map(meta) ->
      ...>     {:ok, meta}
      ...>   (_) ->
      ...>     {
      ...>       :error,
      ...>       Alembic.Error.type(
      ...>         %Alembic.Error{
      ...>           source: %Alembic.Source{
      ...>             pointer: "/meta"
      ...>           }
      ...>         },
      ...>         "object"
      ...>       )
      ...>     }
      ...> end
      iex> json = %{"meta" => "invalid"}
      iex> validate_meta.(json["meta"])
      {
        :error,
        %Alembic.Error{
          detail: "`/meta` type is not object",
          meta: %{
            "type" => "object"
          },
          source: %Alembic.Source{
            pointer: "/meta"
          },
          status: "422",
          title: "Type is wrong"
        }
      }
  """
  @spec type(t, human_type) :: t
  def type(%__MODULE__{source: source = %Source{pointer: pointer}}, human_type) do
    %__MODULE__{
      detail: "`#{pointer}` type is not #{human_type}",
      meta: %{
        "type" => human_type
      },
      source: source,
      status: "422",
      title: "Type is wrong"
    }
  end

  ## Private Functions

  defp path_to_detail(path) when is_list(path) do
    Enum.join(path, " ")
  end

  defimpl Poison.Encoder do
    @doc """
    Encoded `Alembic.Error.t` as a `String.t` contain a JSON objecct where the `nil` fields from `Alembic.Error.t`
    **DO NOT** appear.

    An error can have only a code

        iex> Poison.encode(
        ...>   %Alembic.Error{
        ...>     code: "123"
        ...>   }
        ...> )
        {:ok, "{\\"code\\":\\"123\\"}"}

    An error can have only a detail

        iex> Poison.encode(
        ...>   %Alembic.Error{
        ...>     detail: "`/data` type is not object"
        ...>   }
        ...> )
        {:ok, "{\\"detail\\":\\"`/data` type is not object\\"}"}

    An error can have only an id

        iex> Poison.encode(
        ...>   %Alembic.Error{
        ...>     id: "1"
        ...>   }
        ...> )
        {:ok, "{\\"id\\":\\"1\\"}"}

    An error can have only links

        iex> Poison.encode(
        ...>   %Alembic.Error{
        ...>     links: %{
        ...>       "object" => %Alembic.Link{
        ...>         href: "http://example.com",
        ...>         meta: %{
        ...>           "extra" => "link object"
        ...>         }
        ...>       },
        ...>       "url" => "http://example.com"
        ...>     }
        ...>   }
        ...> )
        {
          :ok,
          "{\\"links\\":{\\"url\\":\\"http://example.com\\",\\"object\\":{\\"meta\\":{\\"extra\\":" <>
          "\\"link object\\"},\\"href\\":\\"http://example.com\\"}}}"
        }

    An error can have only meta

        iex> Poison.encode(
        ...>   %Alembic.Error{
        ...>     meta: %{
        ...>       "extra" => "stuff"
        ...>     }
        ...>   }
        ...> )
        {:ok, "{\\"meta\\":{\\"extra\\":\\"stuff\\"}}"}

    An error can have only a source

        iex> Poison.encode(
        ...>   %Alembic.Error{
        ...>     source: %Alembic.Source{
        ...>       pointer: "/data"
        ...>     }
        ...>   }
        ...> )
        {:ok, "{\\"source\\":{\\"pointer\\":\\"/data\\"}}"}

    An error can have only status

        iex> Poison.encode(
        ...>   %Alembic.Error{
        ...>     status: "422"
        ...>   }
        ...> )
        {:ok, "{\\"status\\":\\"422\\"}"}

    An error can have only title

        iex> Poison.encode(
        ...>   %Alembic.Error{
        ...>     title: "`/errors` type is not array"
        ...>   }
        ...> )
        {:ok, "{\\"title\\":\\"`/errors` type is not array\\"}"}

    """
    def encode(error = %@for{}, options) do
      map = for {field, value} <- Map.from_struct(error), value != nil, into: %{}, do: {field, value}

      Poison.Encoder.Map.encode(map, options)
    end
  end
end
