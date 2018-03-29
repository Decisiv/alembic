defmodule Alembic.TestComment do
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

  schema "comments" do
    field(:text, :string)

    belongs_to(:post, Alembic.TestPost)
  end

  # Functions

  def changeset(changeset = %Changeset{data: %__MODULE__{}}) do
    changeset
    |> validate_length(:text, min: 10)
    |> validate_required(@required_fields)
  end

  def changeset(data, params) do
    data
    |> cast(params, @allowed_fields)
    |> changeset()
  end
end
