defmodule TransportWeb.AOMSView do
  use TransportWeb, :view

  @spec format_bool(nil | boolean()) :: binary()
  def format_bool(nil), do: ""
  def format_bool(true), do: "✅"
  def format_bool(false), do: "❌"
end
