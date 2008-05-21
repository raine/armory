require "net/http"
require "rubygems"
require "hpricot"

class Character
  attr_accessor :name, :guild, :class, :level, :race, :realm, :relevance, :battlegroup
  
  def self.parse_hash(hash)
    char = self.new
    char.name        = hash["name"]
    char.guild       = hash["guild"] unless hash["guild"].empty?
    char.class       = hash["class"].to_sym 
    char.level       = hash["level"].to_i
    char.race        = hash["race"].to_sym
    char.realm       = hash["realm"]
    char.relevance   = hash["relevance"].to_i
    char.battlegroup = hash["battleGroup"]
    
    return char
  end
end

class Armory
  HEADERS = {'User-Agent' => "Mozilla/5.0 (Windows; U; Windows NT 5.1; fi; rv:1.8.1.8) Gecko/20071008 Firefox/2.0.0.8\r\n"}
  REGIONS = {
    :eu => "eu.wowarmory.com",
    :us => "www.wowarmory.com"
  }
  
  def initialize(region)
    raise "invalid region" unless REGIONS.has_key?(region)
    
    @armory_http = start_session(region)
  end
  
  def start_session(reg)
    Net::HTTP.new(REGIONS[reg])
  end
  
  def http_get(path)
    @armory_http.get(path, HEADERS).body
  end
    
  def search(type, query)
    path = "/search.xml?searchQuery=#{query}&searchType="
    
    case type
      when :character
          path << "characters"
          
          xml = Hpricot.XML(http_get(path))
          
          result = parse_search(:character, xml)
          
          return result
      else
        raise "invalid search type"
    end
  end
  
  def parse_search(type, xml)
    case type
      when :character
        characters = []
        characters_xml = (xml/:armorySearch/:searchResults/:characters/:character)
        
        characters_xml.each do |e|
          characters << Character::parse_hash(e.attributes)
        end
        
        return characters
    end
  end
end
