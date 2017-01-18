defmodule Sitesx.Domain do
  import PublicSuffix
  import Chexes, only: [present?: 1]

  alias Oceanex.Resource.DomainRecord

  require Logger

  @domain Application.get_env(:sitesx, :domain)

  def extract_domain(host) do
    host
    |> String.downcase
    |> registrable_domain(ignore_private: true)
    |> String.split(".")
    |> List.first
  end

  def extract_subdomain(conn) do
    domain = "#{registrable_domain(conn.host)}"
    prefix = String.replace conn.host, ~r/#{domain}|\./, ""
    qstr   = conn.params["sub"]

    cond do
      prefix != ""   -> prefix
      present?(qstr) -> qstr
      true           -> nil
    end
  end

  def ensured_domain?(host) do
    case :inet_res.nslookup('#{host}', 1, :a) do
      {:ok, _}    -> true
      {:error, _} -> false
    end
  end

  def create_subdomain(subdomain, domain \\ @domain) do
    case DomainRecord.all(domain) do
      {:ok, %{body: %{domain_records: records}}} ->
        if Enum.filter(records, & &1[:name] == domain) <= 0 do
          record =
            records
            |> Enum.filter(& &1[:name] == "@")
            |> Enum.filter(& &1[:type] == "A")
            |> List.first
            |> Kernel.||(%{})
            |> Map.delete(:id)
            |> Map.merge(%{name: subdomain})

          DomainRecord.create domain, record
        else
          {:error, "duplicated subdomain"}
        end

      {:ok, %{body: %{id: reason}}} ->
        {:error, "#{domain}: #{reason}"}

      unknown ->
        Logger.error inspect(unknown)
        {:error, "unknown error"}
    end
  end

end