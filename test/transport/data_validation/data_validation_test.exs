defmodule Transport.DataValidationTest do
  use ExUnit.Case, async: false
  use TransportWeb.ExternalCase
  alias Transport.DataValidation

  doctest DataValidation

  test "finds a project" do
    use_cassette "data_validation/find_project-ok" do
      assert {:ok, project} = DataValidation.find_project("transport")
      assert project.name == "transport"
      refute is_nil(project.id)
    end
  end

  test "creates a project" do
    use_cassette "data_validation/create_project-ok" do
      assert {:ok, project} = DataValidation.create_project(%{name: "transport"})
      assert project.name == "transport"
      refute is_nil(project.id)
    end
  end
end
