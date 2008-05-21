class Armory
  REGIONS = {
    :eu => "eu.wowarmory.com",
    :us => "wowarmory.com"
  }
  
  def initialize(region)
    raise "invalid region" unless REGIONS.has_key?(region)
  end
  
  
end

Armory.new(:eu)