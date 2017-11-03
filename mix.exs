defmodule IcalendarEventOccurrence.Mixfile do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :icalendar_event_occurrence,
      version: @version,
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      name: "ICalendar Event Occurrence",
      source_url: "https://github.com/lpil/icalendar_event_occurrence",
      description: "Provides ability to derive Calendar Event occurrences based on RRULE, etc.",
      package: [
        maintainers: ["Walter McGinnis"],
        licenses: ["MIT"],
        links: %{ "GitHub" => "https://github.com/lpil/icalendar_event_occurrence" },
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:icalendar, github: "walter/icalendar", branch: "feature/rrule"}
    ]
  end
end
