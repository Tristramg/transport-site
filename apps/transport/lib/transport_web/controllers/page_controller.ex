defmodule TransportWeb.PageController do
  use TransportWeb, :controller
  alias DB.{AOM, Dataset, Partner, Region, Repo}
  alias Transport.CSVDocuments
  import Ecto.Query

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    conn
    |> assign(:mailchimp_newsletter_url, Application.get_env(:transport, :mailchimp_newsletter_url))
    |> assign(:count_by_type, Dataset.count_by_type())
    |> assign(:count_train, Dataset.count_by_resource_tag("rail"))
    |> assign(:count_boat, Dataset.count_by_resource_tag("ferry"))
    |> assign(:count_coach, Dataset.count_coach())
    |> assign(:count_aoms_with_dataset, count_aoms_with_dataset())
    |> assign(:count_regions_completed, count_regions_completed())
    |> assign(:count_has_realtime, Dataset.count_has_realtime())
    |> assign(:percent_population, percent_population())
    |> assign(:reusers, CSVDocuments.reusers())
    |> render("index.html")
  end

  @spec login(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def login(conn, %{"redirect_path" => redirect_path}) do
    conn
    |> put_session(:redirect_path, redirect_path)
    |> render("login.html")
  end

  @spec partners(Plug.Conn.t()) :: Plug.Conn.t()
  def partners(conn) do
    partners =
      Partner
      |> Repo.all()
      |> Task.async_stream(fn partner -> Map.put(partner, :description, Partner.description(partner)) end)
      |> Task.async_stream(fn {:ok, partner} -> Map.put(partner, :count_reuses, Partner.count_reuses(partner)) end)
      |> Stream.map(fn {:ok, partner} -> partner end)
      |> Enum.to_list()

    conn
    |> assign(:partners, partners)
    |> assign(:page, "partners.html")
    |> render("single_page.html")
  end

  @spec single_page(Plug.Conn.t(), map()) :: Plug.Conn.t()
  defp single_page(conn, %{"page" => page}) do
    conn
    |> assign(:page, page <> ".html")
    |> render("single_page.html")
  end

  @spec real_time(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def real_time(conn, _params) do
    conn
    |> assign(:providers, CSVDocuments.real_time_providers())
    |> single_page(%{"page" => "real_time"})
  end

  @spec conditions(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def conditions(conn, _params), do:  single_page(conn, %{"page" => "conditions"})

  @spec aoms_with_dataset :: Ecto.Query.t()
  defp aoms_with_dataset do
    from(a in AOM,
      join: d in Dataset,
      on: a.id == d.aom_id or not is_nil(a.parent_dataset_id),
      distinct: a.id
    )
  end

  @spec count_aoms_with_dataset :: number()
  defp count_aoms_with_dataset, do: Repo.aggregate(aoms_with_dataset(), :count, :id)

  @spec population_with_dataset :: number()
  defp population_with_dataset, do: Repo.aggregate(aoms_with_dataset(), :sum, :population_totale_2014)

  @spec population_totale :: number()
  defp population_totale, do: Repo.aggregate(AOM, :sum, :population_totale_2014)

  @spec percent_population :: number()
  defp percent_population, do: percent(population_with_dataset(), population_totale())

  @spec percent(number(), number()) :: number()
  defp percent(_a, 0), do: 0
  defp percent(a, b), do: Float.round(a / b * 100, 1)

  @spec count_regions_completed :: number()
  defp count_regions_completed do
    Region
    |> where([r], r.is_completed == true)
    |> Repo.aggregate(:count, :id)
  end
end
