class Reporter
  def generate(dependency_freshness)
    raise NotImplementedError, "Subclasses must implement the generate method"
  end
end
