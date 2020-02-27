defmodule TransportWeb.StatsController do
  alias DB.{AOM, Dataset, Region, Repo, Resource}
  alias Transport.CSVDocuments
  import Ecto.Query
  require Logger
  use TransportWeb, :controller

  @spec index(Plug.Conn.t(), any) :: Plug.Conn.t()
  def index(conn, _params) do
    aoms =
      Repo.all(
        from(a in AOM,
          select: %{
            population: a.population_totale_2014,
            region_id: a.region_id,
            nb_datasets: fragment("SELECT count(*) FROM dataset where aom_id = ?", a.id),
            parent_dataset_id: a.parent_dataset_id
          }
        )
      )

    aoms_with_datasets = aoms |> Enum.filter(&(&1.nb_datasets > 0 || !is_nil(&1.parent_dataset_id)))

    regions = Repo.all(from(r in Region, where: r.nom != "National"))

    render(conn, "index.html",
      nb_datasets: Repo.aggregate(Dataset, :count, :id),
      nb_pt_datasets: Dataset.count_by_type("public-transit"),
      nb_aoms: Enum.count(aoms),
      nb_aoms_with_data: Enum.count(aoms_with_datasets),
      nb_regions: Enum.count(regions),
      nb_regions_completed: regions |> Enum.count(fn r -> r.is_completed end),
      population_totale: get_population(aoms),
      population_couverte: get_population(aoms_with_datasets),
      nb_official_realtime: nb_official_realtime(),
      nb_unofficial_realtime: nb_unofficial_realtime(),
      nb_reusers: nb_reusers(),
      nb_reuses: nb_reuses(),
      nb_dataset_types: nb_dataset_types(),
      nb_gtfs: count_dataset_with_format("GTFS"),
      nb_netex: count_dataset_with_format("netex"),
      nb_bss_datasets: count_dataset_with_format("gbfs"),
      nb_bikes_datasets: nb_bikes(),
      droms: ["antilles", "guyane", "mayotte", "reunion"]
    )
  end

  @spec get_population([Dataset.t()]) :: number()
  defp get_population(datasets) do
    datasets
    |> Enum.reduce(0, &(&1.population + &2))
    |> Kernel./(1_000_000)
    |> Float.round(2)
  end

  @spec nb_official_realtime :: number()
  defp nb_official_realtime do
    rt_datasets =
      from(d in Dataset,
        where: d.has_realtime
      )

    Repo.aggregate(rt_datasets, :count, :id)
  end

  @spec nb_bikes() :: integer
  defp nb_bikes do
    bikes_datasets =
      from(d in Dataset,
        where: d.type == "bike-sharing"
      )

    Repo.aggregate(bikes_datasets, :count, :id)
  end

  @spec nb_unofficial_realtime :: number()
  defp nb_unofficial_realtime, do: Enum.count(CSVDocuments.real_time_providers())

  @spec nb_dataset_types :: number()
  defp nb_dataset_types do
    Dataset
    |> select([d], count(d.type, :distinct))
    |> Repo.one()
  end

  @spec nb_reusers :: number()
  defp nb_reusers, do: Enum.count(CSVDocuments.reusers())

  @spec nb_reuses :: number()
  defp nb_reuses, do: Repo.aggregate(Dataset, :sum, :nb_reuses)

  @spec count_dataset_with_format(binary()) :: number()
  defp count_dataset_with_format(format) do
    Resource
    |> select([r], count(r.dataset_id, :distinct))
    |> where([r], r.format == ^format)
    |> Repo.one()
  end
end
