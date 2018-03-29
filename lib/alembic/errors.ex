defmodule Alembic.Errors do
  @moduledoc """
  List of `Alembic.Error`s, such as for `t:Alembic.Document.t/0` `errors`.
  """

  alias Alembic.Error
  alias Ecto.Changeset

  # Functions

  @doc """
  Converts the `errors` in `ecto_changeset` to `Alembic.Error.t` in a single `t`.

  If only `:format_key` is given in the `options`, then the other keys for
  `t:Alembic.Source.ancestor_descendants_from_ecto_changeset_path_options/0` will be derived from the
  `ecto_schema_module` of the `changeset` `:data`.

      iex> format_key = fn key ->
      ...>   key |> Atom.to_string() |> String.replace("_", "-")
      ...> end
      iex> changeset = Ecto.Changeset.change(%Alembic.TestAuthor{id: 1})
      iex> Alembic.Errors.from_ecto_changeset(
      ...>   %Ecto.Changeset{
      ...>     changeset
      ...>     | errors: [
      ...>         {:name, {"should be at least %{count} character(s)", [count: 2, validation: :length, min: 2]}},
      ...>         {:posts, {"are still associated with this entry", []}}
      ...>       ]
      ...>   },
      ...>   %{
      ...>     association_set: MapSet.new(~w(posts profile)a),
      ...>     association_by_foreign_key: %{},
      ...>     attribute_set: MapSet.new(~w(name)a),
      ...>     format_key: format_key
      ...>   }
      ...> )
      [
        %Alembic.Error{
          detail: "name should be at least 2 character(s)",
          source: %Alembic.Source{
            pointer: "/data/attributes/name"
          },
          title: "should be at least 2 character(s)"
        },
        %Alembic.Error{
          detail: "posts are still associated with this entry",
          source: %Alembic.Source{
            pointer: "/data/relationships/posts"
          },
          title: "are still associated with this entry"
        }
      ]

  If the `ecto_changeset` `data` is not an `Ecto.Schema.t` struct and `__schema__/1` reflection functions are not
  supported, then you can bypass the reflection by giving the
  `t:Alembic.Source.ancestor_descendants_from_ecto_changeset_path_options/0` explicitly.  You'll also need to supply the
  `types` in `Ecto.Changeset.t` `types` key.

      iex> format_key = fn key ->
      ...>   key |> Atom.to_string() |> String.replace("_", "-")
      ...> end
      iex> Alembic.Errors.from_ecto_changeset(
      ...>   %Ecto.Changeset{
      ...>     data: %{id: 1},
      ...>     errors: [
      ...>       {:name, {"should be at least %{count} character(s)", [count: 2, validation: :length, min: 2]}},
      ...>       {:posts, {"are still associated with this entry", []}}
      ...>     ],
      ...>     types: %{
      ...>       id: :id,
      ...>       name: :string,
      ...>       posts: {:assoc,
      ...>         %Ecto.Association.Has{
      ...>           cardinality: :many,
      ...>           field: :posts,
      ...>           on_delete: :nothing,
      ...>           on_replace: :raise,
      ...>           owner: Alembic.TestAuthor,
      ...>           owner_key: :id,
      ...>           queryable: Alembic.TestPost,
      ...>           related: Alembic.TestPost,
      ...>           related_key: :author_id,
      ...>           relationship: :child
      ...>         }},
      ...>       profile: {:assoc,
      ...>         %Ecto.Association.Has{
      ...>           cardinality: :one,
      ...>           field: :profile,
      ...>           on_delete: :nothing,
      ...>           on_replace: :raise,
      ...>           owner: Alembic.TestAuthor,
      ...>           owner_key: :id,
      ...>           queryable: Alembic.TestProfile,
      ...>           related: Alembic.TestProfile,
      ...>           related_key: :author_id,
      ...>           relationship: :child,
      ...>           unique: true
      ...>         }}
      ...>     }
      ...>   },
      ...>   %{
      ...>     association_set: MapSet.new([:posts]),
      ...>     association_by_foreign_key: %{},
      ...>     attribute_set: MapSet.new([:name]),
      ...>     format_key: format_key
      ...>   }
      ...> )
      [
        %Alembic.Error{
          detail: "name should be at least 2 character(s)",
          source: %Alembic.Source{
            pointer: "/data/attributes/name"
          },
          title: "should be at least 2 character(s)"
        },
        %Alembic.Error{
          detail: "posts are still associated with this entry",
          source: %Alembic.Source{
            pointer: "/data/relationships/posts"
          },
          title: "are still associated with this entry"
        }
      ]

  ## Nested Errors

  Errors on nested associations and embeds are traversed and the nested JSON pointer calculated

      iex> format_key = fn key ->
      ...>   key |> to_string() |> String.replace("_", "-")
      ...> end
      iex> post_changeset = Alembic.TestPost.changeset(%Alembic.TestPost{}, %{"text" => "too short"})
      iex> author_changeset = Alembic.TestAuthor.changeset(%Alembic.TestAuthor{}, %{"name" => "A"})
      iex> changeset = Ecto.Changeset.put_assoc(post_changeset, :author, author_changeset)
      iex> Alembic.Errors.from_ecto_changeset(
      ...>   changeset,
      ...>   %{
      ...>     association_set: MapSet.new(~w(author comments tags)a),
      ...>     association_by_foreign_key: %{author_id: :author},
      ...>     attribute_set: MapSet.new(~w(inserted_at text updated_at)a),
      ...>     format_key: format_key
      ...>   }
      ...> )
      [
        %Alembic.Error{
          detail: "author name should be at least 2 character(s)",
          source: %Alembic.Source{
            pointer: "/data/relationships/author/name"
          },
          title: "should be at least 2 character(s)"
        },
        %Alembic.Error{
          detail: "text should be at least 50 character(s)",
          source: %Alembic.Source{
            pointer: "/data/attributes/text"
          },
          title: "should be at least 50 character(s)"
        }
      ]

  Errors on `*_many` associations have a 0-based index assigned in the JSON pointer

      iex> format_key = fn key ->
      ...>   key |> to_string() |> String.replace("_", "-")
      ...> end
      iex> post_changeset = Alembic.TestPost.changeset(%Alembic.TestPost{}, %{"text" => "too short"})
      iex> comment_changeset = Alembic.TestComment.changeset(%Alembic.TestComment{}, %{})
      iex> changeset = Ecto.Changeset.put_assoc(post_changeset, :comments, [comment_changeset])
      iex> Alembic.Errors.from_ecto_changeset(
      ...>   changeset,
      ...>   %{
      ...>     association_set: MapSet.new(~w(author comments tags)a),
      ...>     association_by_foreign_key: %{author_id: :author},
      ...>     attribute_set: MapSet.new(~w(inserted_at text updated_at)a),
      ...>     format_key: format_key
      ...>   }
      ...> )
      [
        %Alembic.Error{
          detail: "comments 0 text can't be blank",
          source: %Alembic.Source{
            pointer: "/data/relationships/comments/0/text"
          },
          title: "can't be blank"
        },
        %Alembic.Error{
          detail: "text should be at least 50 character(s)",
          source: %Alembic.Source{
            pointer: "/data/attributes/text"
          },
          title: "should be at least 50 character(s)"
        }
      ]

  """
  @spec from_ecto_changeset(
          Ecto.Changeset.t(),
          Source.ancestor_descendants_from_ecto_changeset_path_options()
        ) :: [Error.t()]
  def from_ecto_changeset(changeset = %Ecto.Changeset{}, options) when is_map(options) do
    changeset
    |> traverse()
    |> flatten_keys()
    |> titles_by_path_to_titles_by_error_template(options)
    |> from_titles_by_error_template()
  end

  ## Private Functions

  defp flatten_keys(traversed) when is_map(traversed) do
    flatten_keys(traversed, [])
  end

  defp flatten_keys(traversed, prefix_keys) when is_map(traversed) and is_list(prefix_keys) do
    Enum.reduce(traversed, %{}, fn {key, value}, acc ->
      Map.merge(acc, flatten_keys(value, prefix_keys ++ [key]))
    end)
  end

  defp flatten_keys(messages = [message | _], keys) when is_binary(message) do
    %{keys => messages}
  end

  defp flatten_keys(elements, prefix_keys) when is_list(elements) do
    elements
    |> Stream.with_index()
    |> Enum.reduce(%{}, fn {element, index}, acc ->
      Map.merge(acc, flatten_keys(element, prefix_keys ++ [index]))
    end)
  end

  defp from_titles_by_error_template(titles_by_error_template) do
    Enum.flat_map(titles_by_error_template, &from_error_template_titles/1)
  end

  defp from_error_template_titles({error_template = %Error{detail: template_detail}, titles})
       when is_list(titles) do
    Enum.map(titles, fn title when is_binary(title) ->
      %Error{error_template | detail: template_detail <> " " <> title, title: title}
    end)
  end

  def titles_by_path_to_titles_by_error_template(titles_by_path, options)
      when is_map(titles_by_path) do
    Enum.into(titles_by_path, %{}, fn {path, titles} ->
      error_template = Error.from_ecto_changeset_path(path, options)
      {error_template, titles}
    end)
  end

  defp traverse(changeset) do
    Changeset.traverse_errors(changeset, fn error ->
      Error.title_from_ecto_changeset_error_message(error)
    end)
  end
end
