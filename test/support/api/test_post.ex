defmodule Alembic.TestPost do
  @moduledoc """
  A schema used in examples in `Alembic`
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Ecto.Changeset

  # Constants

  @optional_fields ~w()a
  @required_fields ~w(text)a
  @allowed_fields @optional_fields ++ @required_fields

  # Schema

  schema "posts" do
    field(:text, :string)

    timestamps()

    belongs_to(:author, Alembic.TestAuthor)
    has_many(:comments, Alembic.TestComment)
    many_to_many(:tags, Alembic.TestTag, join_through: "posts_tags", on_replace: :delete)
  end

  # Functions

  def changeset(changeset = %Changeset{data: %__MODULE__{}}) do
    changeset
    |> validate_length(:text, min: 50)
    |> validate_required(@required_fields)
  end

  def changeset(data, params) do
    data
    |> cast(params, @allowed_fields)
    |> changeset()
  end
end
