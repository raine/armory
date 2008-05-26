require "net/http"
require "rubygems"
require "hpricot"
require "erb"

TALENT_TREES = {
  :druid   => [:balance, :feral, :restoration],
  :hunter  => [:"beast mastery", :marksmanship, :survival],
  :mage    => [:arcane, :fire, :frost],
  :paladin => [:holy, :protection, :retribution],
  :priest  => [:discipline, :holy, :shadow],
  :rogue   => [:assasination, :combat, :subtlety],
  :shaman  => [:elemental, :enhancement, :restoration],
  :warlock => [:affliction, :demonology, :destruction],
  :warrior => [:arms, :fury, :protection]
}

SPELL_SCHOOLS = %w(arcane fire frost holy nature shadow)

RACES = ["tauren", "undead", "troll", "blood elf", "orc",
         "human", "night elf", "gnome", "dwarf", "draenei"]
         
CLASSES = ["rogue", "shaman", "warlock", "mage", "druid",
           "warrior", "hunter", "priest", "paladin"]

module Utilities  
  def self.coeff(size)
    case size
    when 2
      return 0.76
    when 3
      return 0.88
    when 5
      return 1
    end
  end
  
  def self.rating_to_points(rating)    
    if rating <= 1500
      points = 0.22*rating+14
    else
      points = (1511.26/(1+1639.28*2.71828**(-0.00412*rating)))
    end
    
    teams = Hash.new
    
    [2, 3, 5].each do |s|
      points_coeff = coeff(s)*points
      
      if points_coeff > 0
        teams[s] = points_coeff.round
      else
        teams[s] = 0
      end
    end
    
    teams
  end
  
  def self.points_to_rating(points)
    raise "invalid input" if points < 0 || points > 1148
    
    teams = Hash.new
    
    [2, 3, 5].each do |s|
      rating = Math.log((1511.26/(1639.28*points/coeff(s)))-(1/1639.28))/(-0.00412)  
      rating = ((points/coeff(s))-14)/0.22 if rating <= 1500
      
      teams[s] = rating.round
    end
    
    teams
  end
end

class Character
  attr_accessor :name, :guild, :char_class,
                :level, :race, :realm,
                :relevance, :battlegroup, :region,
                :search_rank, :title, :gender,
                :talents, :pvp, :professions,
                :stats, :spell, :resistances,
                :melee, :ranged, :defenses,
                :arena_teams, :arena_games_total, :arena_games_won,
                :arena_games_lost, :fetched_at
                
  def initialize
    @professions = Array.new
    @talents     = Array.new
    @spell       = Hash.new
    @melee       = Hash.new
    @arena_teams = Hash.new
    @ranged      = Hash.new
    @resistances = Hash.new
    @defenses    = Hash.new 
  end
  
  def self.parse_hash(hash)
    char = self.new
    char.name = hash["name"]
    
    if hash["guild"] && hash["guild"].empty?
      char.guild = hash["guild"]
    elsif hash["guildName"] && hash["guildName"].empty? 
      char.guild = hash["guildName"]
    end
    
    char.char_class  = hash["class"].downcase.to_sym 
    char.level       = hash["level"].to_i if hash["level"]
    char.race        = hash["race"].to_sym
    char.realm       = hash["realm"] if hash["realm"]
    char.relevance   = hash["relevance"].to_i if hash["level"]
    char.battlegroup = hash["battleGroup"]
    char.search_rank = hash["searchRank"].to_i if hash["searchRank"]
    
    if hash["seasonGamesPlayed"]
      char.arena_games_total = hash["seasonGamesPlayed"].to_i
      char.arena_games_won   = hash["seasonGamesWon"].to_i
      char.arena_games_lost  = hash["seasonGamesPlayed"].to_i-hash["seasonGamesWon"].to_i
    end

    return char
  end
  
  def caster?
    case self.char_class
    when :mage
      true
    when :warlock
      true
    when :priest
      true
    when :shaman
      true if self.spec == :elemental or self.spec == :restoration
    when :paladin
      true if self.spec == :holy
    when :druid
      true if self.spec == :balance or self.spec == :restoration
    else
      false
    end
  end
  
  def healer?
    case self.char_class
    when :druid
      true if self.spec == :restoration
    when :priest
      true if self.spec == :discipline or self.spec == :holy
    when :shaman
      true if self.spec == :restoration
    when :paladin
      true if self.spec == :holy
    else
      false
    end
  end
  
  def spell_schools
    schools = {
      :warlock => [:fire, :shadow],
      :priest  => [:holy, :shadow],
      :shaman  => [:elemental, :nature],
      :mage    => [:frost, :arcane, :fire],
      :druid   => [:nature, :arcane]
    }
    
    return self.spell[:damage].delete_if { |k,v| !schools[self.char_class].include?(k) }
  end
  
  def spec
    sorted = self.talents.sort_by {|tree| tree[:points]}.reverse
    
    sorted.first[:tree]
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
    
    @region = region
    @armory_http = start_session(region)
  end
    
  def start_session(reg)
    Net::HTTP.new(REGIONS[reg])
  end
  
  def http_get(path)    
    res = @armory_http.get(path, HEADERS)
    
    raise "armory fails" unless res.code_type == Net::HTTPOK
    
    return res.body
  end
  
  def get_character(page, name, realm)
    pp "/character-#{page.to_s}.xml?r=#{ERB::Util.url_encode(realm)}&n=#{name}"
    http_get("/character-#{page.to_s}.xml?r=#{ERB::Util.url_encode(realm)}&n=#{name}")
  end
  
  def character(name, realm)
    @char = Character.new
    @char.region = @region
    @char.fetched_at = Time.now
    
    sheet_xml = get_character(:sheet, name, realm)
    
    parse_character(:sheet, sheet_xml)
    
    return @char
  end
  
  def parse_character(page, xml)
    xml = Hpricot.XML(xml)
    
    case page
      when :sheet
        character_info = (xml/:characterInfo).first.attributes
        
        raise character_info["errCode"] if character_info["errCode"]
        
        char_hash = (xml/:characterInfo/:character).first.attributes
        
        @char.name        = char_hash["name"]
        @char.char_class  = char_hash["class"].downcase.to_sym
        @char.race        = char_hash["race"].downcase.to_sym
        @char.guild       = char_hash["guildName"]
        @char.level       = char_hash["level"].to_i
        @char.gender      = char_hash["gender"].downcase.to_sym
        @char.realm       = char_hash["realm"]
        @char.battlegroup = char_hash["battleGroup"]
        
        @char.title = {:prefix => char_hash["prefix"],
                       :suffix => char_hash["suffix"]}
        
        tab_xml = (xml/:characterInfo/:characterTab)
        
        raise "character data unavailable" if tab_xml.empty?
        
        # talents
        talents = (tab_xml/:talentSpec).first.attributes
        talents = [talents["treeOne"], talents["treeTwo"], talents["treeThree"]]
        
        trees = TALENT_TREES[@char.char_class]
        trees.each_with_index do |tree,i|
          @char.talents << {:tree => tree, :points => talents[i].to_i}
        end
        
        # pvp stats
        pvp = (tab_xml/:pvp)
        
        @char.pvp = {:lifetime_kills => (pvp/:lifetimehonorablekills).first.attributes["value"].to_i,
                      :arena_points   => (pvp/:arenacurrency).first.attributes["value"].to_i}

        # professions
        prof = (tab_xml/:professions/:skill)
        prof.each do |p|
          @char.professions << {:name => p["key"].to_sym, :value => p["value"].to_i, :max => p["max"].to_i}
        end
        
        # stats
        bars = (tab_xml/:characterBars)
        @char.stats = {:health => (bars/:health).first.attributes["effective"].to_i}
        
        # if power's type is mana, add mana and mana regen as stats
        if (bars/:secondBar).first.attributes["type"] == "m"
          power = (bars/:secondBar).first.attributes
          @char.stats[:mana] = power["effective"].to_i
           
          @char.spell[:mp5]    = power["casting"].to_i
          @char.spell[:mp5_nc] = power["notCasting"].to_i
        end
        
        basestats = (tab_xml/:baseStats)
        
        %w(strength agility stamina intellect spirit).each do |s|
          stat = (basestats/s.to_sym).first.attributes
          @char.stats[s.to_sym] = {:base => stat["base"].to_i, :effective => stat["effective"].to_i}
        end
      
        resistances = (tab_xml/:resistances)
        
        SPELL_SCHOOLS.each do |s|
          resist = (resistances/s.to_sym).first.attributes
          @char.resistances[s.to_sym] = resist["value"].to_i
        end
        
        # melee stuff
        melee_xml = (tab_xml/:melee)
        
        melee = Hash.new
        
        %w(power hitRating critChance expertise).each do |e|
          melee[e] = (melee_xml/e.to_sym).first.attributes
        end
        
        @char.melee[:attack_power] = {:base => melee["power"]["base"].to_i,
                                      :effective => melee["power"]["effective"].to_i}
        @char.melee[:crit]         = {:rating => melee["critChance"]["rating"].to_i,
                                      :percent => melee["critChance"]["percent"].to_f}
        @char.melee[:hit_rating]   = {:value => melee["hitRating"]["value"].to_i,
                                      :inc_percent => melee["hitRating"]["increasedHitPercent"].to_f}
        @char.melee[:expertise]    = {:value => melee["expertise"]["value"].to_i,
                                      :rating => melee["expertise"]["rating"].to_i}
        
        # ranged stuff
        ranged_xml = (tab_xml/:ranged)
        ranged     = Hash.new
        
        %w(power hitRating critChance).each do |e|
          ranged[e] = (ranged_xml/e.to_sym).first.attributes
        end
        
        @char.ranged[:attack_power] = {:base => ranged["power"]["base"].to_i,
                                      :effective => ranged["power"]["effective"].to_i}
        @char.ranged[:crit]         = {:rating => ranged["critChance"]["rating"].to_i,
                                      :percent => ranged["critChance"]["percent"].to_f}
        @char.ranged[:hit_rating]   = {:value => ranged["hitRating"]["value"].to_i,
                                      :inc_percent => ranged["hitRating"]["increasedHitPercent"].to_f}
        
        # spell stuff
        spell_xml = (tab_xml/:spell)
        
        spell_damage_xml = (spell_xml/:bonusDamage)
        spell_damage     = Hash.new
        
        SPELL_SCHOOLS.each do |e|
          spell_damage[e.to_sym] = (spell_damage_xml/e.to_sym).first.attributes["value"].to_i
        end
        
        @char.spell[:damage] = spell_damage

        healing = (spell_xml/:bonusHealing).first.attributes
        @char.spell[:healing] = healing["value"].to_i
        
        
        hit_rating = (spell_xml/:hitRating).first.attributes
        @char.spell[:hit_rating] = {:value => hit_rating["value"].to_i,
                                    :inc_percent => hit_rating["increasedHitPercent"].to_f}
        
        spell_crit_xml = (spell_xml/:critChance)
        @char.spell[:crit] = {:rating => spell_crit_xml.first.attributes["rating"].to_i, :schools => Hash.new}
        
        SPELL_SCHOOLS.each do |e|
          @char.spell[:crit][:schools][e.to_sym] = (spell_crit_xml/e.to_sym).first.attributes["percent"].to_f
        end
        
        penetration = (spell_xml/:penetration).first.attributes
        @char.spell[:penetration] = penetration["value"].to_i
        
        # defense stuff
        defenses_xml = (tab_xml/:defenses)
        defenses     = Hash.new
        
        %w(armor defense resilience).each do |e|
          defenses[e] = (defenses_xml/e.to_sym).first.attributes
        end
        
        @char.defenses[:armor] = {:base      => defenses["armor"]["base"].to_i,
                                  :effective => defenses["armor"]["effective"].to_i,
                                  :percent   => defenses["armor"]["percent"].to_f}
                                  
        @char.defenses[:defense] = {:value       => defenses["defense"]["value"].to_f,
                                    :plus_def    => defenses["defense"]["plusDefense"].to_i,
                                    :rating      => defenses["defense"]["rating"].to_i,
                                    :inc_percent => defenses["defense"]["incPercent"].to_f,
                                    :dec_percent => defenses["defense"]["decPercent"].to_f}
        
        @char.defenses[:resilience] = {:value       => defenses["resilience"]["value"].to_i,
                                       :hit_percent => defenses["resilience"]["hitPercent"].to_f,
                                       :dmg_percent => defenses["resilience"]["damagePercent"].to_f}
        
        %w(dodge parry block).each do |e|
          stat = (defenses_xml/e.to_sym).first.attributes
          @char.defenses[e.to_sym] = {:rating  => stat["rating"].to_i,
                                      :percent => stat["percent"].to_f}
        end
        
        # arena teams
        
        teams_xml = (xml/:characterInfo/:character/:arenaTeams/:arenaTeam)
        teams_xml.each do |team|
          team_obj = ArenaTeam::parse_hash(team.attributes)
        
          members_xml = (team/:members/:character)
          members_xml.each do |member|
            char = Character::parse_hash(member.attributes)
            char.realm  = @char.realm
            char.region = @region
            
            team_obj.members << char
          end
          
          @char.arena_teams[team_obj.type] = team_obj
        end
    end
  end
      
  def search(type, query)
    path = "/search.xml?searchQuery=#{query}&searchType="
    
    case type
      when :character
          path << "characters"
          
          result = parse_search(:character, http_get(path))
          
          return result
      else
        raise "invalid search type"
    end
  end
  
  def parse_search(type, xml)
    xml = Hpricot.XML(xml)
    
    case type
      when :character
        characters = []
        characters_xml = (xml/:armorySearch/:searchResults/:characters/:character)
        
        characters_xml.each do |e|
          characters << Character::parse_hash(e.attributes)
        end
        
        characters.map { |c| c.region = @region }
        
        return characters
    end
  end
end
class ArenaTeam
  attr_accessor :name, :battlegroup, :rating,
                :realm, :faction, :rank,
                :type, :games, :members
  
  def initialize
    @games   = Hash.new
    @members = Array.new
  end
  
  def self.parse_hash(hash)
    team = self.new
    team.name        = hash["name"]
    team.battlegroup = hash["battleGroup"]
    team.rating      = hash["rating"].to_i
    team.realm       = hash["realm"]
    team.faction     = hash["faction"].downcase.to_sym
    team.rank        = hash["ranking"].to_i
    team.type        = hash["size"].to_i
    
    team.games[:season] = {
      :won   => hash["seasonGamesWon"].to_i,
      :lost  => hash["seasonGamesPlayed"].to_i - hash["seasonGamesWon"].to_i,
      :total => hash["seasonGamesPlayed"].to_i
    }
    
    team.games[:week] = {
      :won   => hash["gamesWon"].to_i,
      :lost  => hash["gamesPlayed"].to_i - hash["gamesWon"].to_i,
      :total => hash["gamesPlayed"].to_i
    }

    return team
  end
  
  
end

class Cache
  attr_writer :expires_in
  
  def initialize
    @contents = []
    
    @expires_in = 300
  end
  
  def delete_expired
    @contents.delete_if { |e| Time.now-e[:timestamp]>@expires_in }
  end
  
  def clear
    @contents.clear
  end
  
  def size
    delete_expired
    @contents.size
  end
  
  def add(obj)
    @contents << {:timestamp => Time.now, :item => obj}
  end
  
  def items
    delete_expired
    @contents.map { |i| i[:item] }
  end
end

class CharacterCache<Cache
  def exist?(*info)
    if find_character(*info)
      true
    else
      false
    end
  end
  
  def find_character(name, realm, region)    
    res = items.select { |c| c.name.downcase   == name.downcase &&
                             c.realm.downcase  == realm.downcase &&
                             c.region          == region }
    if res.empty?
      false
    else
      res.first
    end
  end
  
  def save_character(char)
    unless find_character(char.name, char.realm, char.region)
      # character doesn't exist in the cache
      add char
    end
  end
end