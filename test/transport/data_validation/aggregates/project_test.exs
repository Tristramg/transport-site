defmodule Transport.DataValidation.Aggregates.ProjectTest do
  use ExUnit.Case, async: false
  use TransportWeb.ExternalCase
  alias Transport.DataValidation.Aggregates.Project
  alias Transport.DataValidation.Commands.{CreateProject, ValidateFeedVersion}
  alias Transport.DataValidation.Queries.FindProject

  doctest Project

  @tag :capture_log
  describe "init" do
    test "when API is not available it fails" do
      {:ok, pid} = start_supervised({Project, "transport"})
      ref        = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :econnrefused}
    end
  end

  test "find a project" do
    project = %Project{id: "1"}
    assert {:reply, {:ok, ^project}, ^project} = Project.handle_call({:find_project}, nil, project)
  end

  describe "create a project" do
    test "when the project does not exist it creates it" do
      use_cassette "data_validation/aggregates/project/create_project" do
        project = %Project{id: nil}
        command = %CreateProject{name: "transport"}
        assert {:noreply, project} = Project.handle_cast({:create_project, command}, project)
        refute is_nil(project.id)
      end
    end

    test "when the project already exists it serves it from memory" do
      project = %Project{id: "1"}
      command = %CreateProject{name: "transport"}
      assert {:noreply, ^project} = Project.handle_cast({:create_project, command}, project)
    end

    test "when the API is not available it fails" do
      project = %Project{id: nil}
      command = %CreateProject{name: "transport"}
      assert {:stop, :econnrefused, ^project} = Project.handle_cast({:create_project, command}, project)
    end
  end

  describe "validate a feed version" do
    test "when the feed version exists it validates it" do
      project = %Project{id: "1"}
      command = %ValidateFeedVersion{id: "1"}
      assert {:noreply, ^project} = Project.handle_cast({:validate_feed_version, command}, project)
    end

    test "when the feed version does not exist it fails" do
      project = %Project{id: "1"}
      command = %ValidateFeedVersion{id: "2"}
      assert {:stop, _, ^project} = Project.handle_cast({:validate_feed_version, command}, project)
    end
  end

  describe "populate project" do
    test "it calls the API to retrieve the project" do
      use_cassette "data_validation/aggregates/project/populate_project" do
        project = %Project{}
        query   = %FindProject{name: "transport"}
        assert {:noreply, project} = Project.handle_cast({:populate_project, query}, project)
        refute is_nil(project.id)
      end
    end

    test "when the API is not available it fails" do
      project = %Project{}
      query   = %FindProject{name: "transport"}
      assert {:stop, :econnrefused, ^project} = Project.handle_cast({:populate_project, query}, project)
    end
  end
end
