require "net/http"
require "rubygems"
require "hpricot"
require "shorturl"
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

BATTLEGROUPS = %w(bloodlust cyclone emberstorm nightfall rampage reckoning retaliation ruin shadowburn stormstrike vindication whirlwind blackout conviction misery todbringer blutdurst raserel verderbnis glutsturm schattenbrand hinterhalt sturmangriff cataclysme férocité vengeance némésis représailles crueldad)

SPELL_SCHOOLS = %w(arcane fire frost holy nature shadow)

RACES = ["tauren", "undead", "troll", "blood elf", "orc",
         "human", "night elf", "gnome", "dwarf", "draenei"]
         
CLASSES = ["rogue", "shaman", "warlock", "mage", "druid",
           "warrior", "hunter", "priest", "paladin"]
           
GEAR = {
  :pve => {
    4 => [28963, 28964, 28966, 28967, 28968, 29011, 29012, 29015,
          29016, 29017, 29019, 29020, 29021, 29022, 29023, 29028,
          29029, 29030, 29031, 29032, 29033, 29034, 29035, 29036,
          29037, 29038, 29039, 29040, 29042, 29043, 29044, 29045,
          29046, 29047, 29048, 29049, 29050, 29053, 29054, 29055,
          29056, 29057, 29058, 29059, 29060, 29061, 29062, 29063,
          29064, 29065, 29066, 29067, 29068, 29069, 29070, 29071,
          29072, 29073, 29074, 29075, 29076, 29077, 29078, 29079,
          29080, 29081, 29082, 29083, 29084, 29085, 29086, 29087,
          29088, 29089, 29090, 29091, 29092, 29093, 29094, 29095,
          29096, 29097, 29098, 29099, 29100],
    5 => [30113, 30114, 30115, 30116, 30117, 30118, 30119, 30120,
          30121, 30122, 30123, 30124, 30125, 30126, 30127, 30129,
          30130, 30131, 30132, 30133, 30134, 30135, 30136, 30137,
          30138, 30139, 30140, 30141, 30142, 30143, 30144, 30145,
          30146, 30148, 30149, 30150, 30151, 30152, 30153, 30154,
          30159, 30160, 30161, 30162, 30163, 30164, 30165, 30166,
          30167, 30168, 30169, 30170, 30171, 30172, 30173, 30185,
          30189, 30190, 30192, 30194, 30196, 30205, 30206, 30207,
          30210, 30211, 30212, 30213, 30214, 30215, 30216, 30217,
          30219, 30220, 30221, 30222, 30223, 30228, 30229, 30230,
          30231, 30232, 30233, 30234, 30235],
    6 => [30969, 30970, 30972, 30974, 30975, 30976, 30977, 30978,
          30979, 30980, 30982, 30983, 30985, 30987, 30988, 30989,
          30990, 30991, 30992, 30993, 30994, 30995, 30996, 30997,
          30998, 31001, 31003, 31004, 31005, 31006, 31007, 31008,
          31011, 31012, 31014, 31015, 31016, 31017, 31018, 31019,
          31020, 31021, 31022, 31023, 31024, 31026, 31027, 31028,
          31029, 31030, 31032, 31034, 31035, 31037, 31039, 31040,
          31041, 31042, 31043, 31044, 31045, 31046, 31047, 31048,
          31049, 31050, 31051, 31052, 31053, 31054, 31055, 31056,
          31057, 31058, 31059, 31060, 31061, 31063, 31064, 31065,
          31066, 31067, 31068, 31069, 31070, 34431, 34432, 34433,
          34434, 34435, 34436, 34437, 34438, 34439, 34441, 34442,
          34443, 34444, 34445, 34446, 34447, 34448, 34485, 34487,
          34488, 34527, 34528, 34541, 34542, 34543, 34545, 34546,
          34547, 34549, 34554, 34555, 34556, 34557, 34558, 34559,
          34560, 34561, 34562, 34563, 34564, 34565, 34566, 34567,
          34568, 34569, 34570, 34571, 34572, 34573, 34574, 34575]
  },
  :arena => {
    1 => [28334, 28335, 28331, 28332, 28333, 28126, 28127, 28128,
          28129, 28130, 24556, 24553, 24555, 24554, 24552, 30186,
          30187, 30188, 30200, 30201, 31375, 31376, 31377, 31378,
          31379, 27702, 27703, 27704, 27705, 27706, 25834, 25830,
          25833, 25832, 25831, 25997, 26000, 25998, 26001, 25999,
          27469, 27470, 27471, 27472, 27473, 31409, 31410, 31411,
          31412, 31413, 31613, 31614, 31616, 31618, 31619, 24544,
          24549, 24545, 24547, 24546, 31396, 31397, 31400, 31406,
          31407, 27707, 27708, 27709, 27710, 27711, 27879, 27880,
          27881, 27882, 27883, 25854, 25855, 25857, 25856, 25858,
          28136, 28137, 28138, 28139, 28140],          
    2 => [31960, 31961, 31962, 31963, 31964, 31967, 31968, 31969,
          31971, 31972, 31973, 31974, 31975, 31976, 31977, 31979,
          31980, 31981, 31982, 31983, 31987, 31988, 31989, 31990,
          31991, 31992, 31993, 31997, 31995, 31996, 31998, 31999,
          32000, 32001, 32002, 32004, 32005, 32006, 32007, 32008,
          32009, 32010, 32011, 32012, 32013, 32015, 32016, 32017,
          32018, 32019, 32020, 32021, 32022, 32023, 32024, 30486,
          30487, 30488, 30489, 30490, 32029, 32030, 32031, 32032,
          32033, 32034, 32035, 32036, 32037, 32038, 32039, 32040,
          32041, 32042, 32043, 32047, 32048, 32049, 32050, 32051,
          32056, 32057, 32058, 32059, 32060],         
    3 => [33664, 33665, 33666, 33667, 33668, 33671, 33672, 33673,
          33674, 33675, 33676, 33677, 33678, 33679, 33680, 33682,
          33683, 33684, 33685, 33686, 33690, 33691, 33692, 33693,
          33694, 33695, 33696, 33697, 33698, 33699, 33700, 33701,
          33702, 33703, 33704, 33706, 33707, 33708, 33709, 33710,
          33711, 33712, 33713, 33714, 33715, 33717, 33718, 33719,
          33720, 33721, 33722, 33723, 33724, 33725, 33726, 33728,
          33729, 33730, 33731, 33732, 33738, 33739, 33740, 33741,
          33742, 33744, 33745, 33746, 33747, 33748, 33749, 33750,
          33751, 33752, 33753, 33757, 33758, 33759, 33760, 33761,
          33767, 33768, 33769, 33770, 33771]
  }
}

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
  attr_accessor :name, :guild, :gear,
                :level, :race, :realm,
                :relevance, :battlegroup, :region,
                :search_rank, :title, :gender,
                :talents, :pvp, :professions,
                :stats, :spell, :resistances,
                :melee, :ranged, :defenses,
                :arena_teams, :arena_games_total, :arena_games_won,
                :arena_games_lost, :fetched_at, :items
                
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
  
  def to_sym
    self.class.to_s.downcase.to_sym
  end
  
  def check_gear
    # checks characters items for arena or raid gear
    
    @gear = Hash.new

    GEAR.keys.each do |type|
      @gear[type] = Hash.new
      
      GEAR[type].keys.each do |i|
        item_ids = @items.map { |item| item.armory_id  }
        items = GEAR[type][i].find_all {|e| item_ids.include?(e)}.size

        @gear[type][i] = items
      end
    end
  end
  
  def talents_exact
    unless @talents_hash
      blizzard_hash = Armory.new(@region).talents(@name, @realm)
      
      @talents_hash = {:blizzard => blizzard_hash,
                       :wowhead  => self.class.to_s.downcase+'-'+blizzard_hash}
                       
      @talents_hash[:tinyurl] = ShortURL.shorten("http://www.wowhead.com/?talent="+@talents_hash[:wowhead], :fyad)
    end
    
    @talents_hash[:tinyurl]
  end
  
  def url
    @armory_url = ShortURL::shorten('http://'+Armory::REGIONS[@region]+
                  '/character-sheet.xml?r='+ERB::Util.url_encode(@realm)+'&n='+@name, :fyad) if @armory_url.nil?
    @armory_url
  end
  
  def tank?
    false
  end
  
  def healer?
    false
  end
  
  def caster?
    false
  end
  
  def schools
    []
  end
  
  def self.parse_hash(hash)
    char = self.new
    char.name = hash["name"]
    
    if hash["guild"] && !hash["guild"].empty?
      char.guild = hash["guild"]
    elsif hash["guildName"] && !hash["guildName"].empty? 
      char.guild = hash["guildName"]
    end
    
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
  
  def spec
    sorted = self.talents.sort_by {|tree| tree[:points]}.reverse
    
    sorted.first[:tree]
  end
end

class Druid<Character
  def schools
    [:nature, :arcane]
  end
  
  def caster?
    spec  == :balance or spec == :restoration
  end
  
  def healer?
    spec == :restoration
  end
  
  def tank?
    spec == :feral
  end
end

class Hunter<Character
end

class Mage<Character
  def schools
    [:frost, :arcane, :fire]
  end
  
  def caster?
    true
  end
end

class Paladin<Character
  def healer?
    spec == :holy
  end
  
  def tank?
    spec == :protection
  end
end

class Priest<Character
  def schools
    [:holy, :shadow]
  end
  
  def caster?
    true
  end
  
  def healer?
    spec == :holy or spec == :discipline
  end
end

class Rogue<Character
end

class Shaman<Character
  def schools
    [:nature]
  end
  
  def caster?
    spec == :elemental or spec == :restoration
  end
  
  def healer?
    spec == :restoration
  end
end

class Warlock<Character
  def schools
    [:fire, :shadow]
  end
  
  def caster?
    true
  end
end

class Warrior<Character
  def tank?
    true if spec == :protection
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
    http = Net::HTTP.new(REGIONS[reg])
    http.open_timeout = 10
    
    return http
  end
  
  def http_get(path)
    begin
      res = @armory_http.get(path, HEADERS)
    rescue Timeout::Error
      raise "timeout"
    end
    
    raise "armory fails" unless res.code_type == Net::HTTPOK
    
    return res.body
  end
  
  def get_character(page, name, realm)
    http_get("/character-#{page.to_s}.xml?r=#{ERB::Util.url_encode(realm)}&n=#{name}")
  end
  
  def character(name, realm)
    sheet_xml = get_character(:sheet, name, realm)
    char = parse_character(:sheet, sheet_xml)
    
    return char
  end
  
  def talents(name, realm)
    sheet_xml = get_character(:talents, name, realm)
    talents = parse_character(:talents, sheet_xml)
    
    return talents
  end
  
  def parse_character(page, xml)
    xml = Hpricot.XML(xml)
    
    case page
      when :talents
        return (xml/:characterInfo/:talentTab/:talentTree).first.attributes["value"]
      when :sheet
        character_info = (xml/:characterInfo).first.attributes
        
        raise character_info["errCode"] if character_info["errCode"]
        
        char_hash = (xml/:characterInfo/:character).first.attributes
        
        char_class = char_hash["class"].downcase.to_sym
        
        char = Object.const_get(char_class.to_s.capitalize).new
        
        char.region = @region
        char.fetched_at = Time.now
        
        char.name        = char_hash["name"]
        char.race        = char_hash["race"].downcase.to_sym
        char.guild       = char_hash["guildName"]
        char.level       = char_hash["level"].to_i
        char.gender      = char_hash["gender"].downcase.to_sym
        char.realm       = char_hash["realm"]
        char.battlegroup = char_hash["battleGroup"]
        
        char.title = {:prefix => char_hash["prefix"],
                      :suffix => char_hash["suffix"]}
        
        tab_xml = (xml/:characterInfo/:characterTab)
        
        raise "character data unavailable" if tab_xml.empty?
        
        # talents
        talents = (tab_xml/:talentSpec).first.attributes
        talents = [talents["treeOne"], talents["treeTwo"], talents["treeThree"]]
        
        trees = TALENT_TREES[char.to_sym]
        trees.each_with_index do |tree,i|
          char.talents << {:tree => tree, :points => talents[i].to_i}
        end
        
        # pvp stats
        pvp = (tab_xml/:pvp)
        
        char.pvp = {:lifetime_kills => (pvp/:lifetimehonorablekills).first.attributes["value"].to_i,
                      :arena_points   => (pvp/:arenacurrency).first.attributes["value"].to_i}

        # professions
        prof = (tab_xml/:professions/:skill)
        prof.each do |p|
          char.professions << {:name => p["key"].to_sym, :value => p["value"].to_i, :max => p["max"].to_i}
        end
        
        # stats
        bars = (tab_xml/:characterBars)
        char.stats = {:health => (bars/:health).first.attributes["effective"].to_i}
        
        # if power's type is mana, add mana and mana regen as stats
        if (bars/:secondBar).first.attributes["type"] == "m"
          power = (bars/:secondBar).first.attributes
          char.stats[:mana] = power["effective"].to_i
           
          char.spell[:mp5]    = power["casting"].to_i
          char.spell[:mp5_nc] = power["notCasting"].to_i
        end
        
        basestats = (tab_xml/:baseStats)
        
        %w(strength agility stamina intellect spirit).each do |s|
          stat = (basestats/s.to_sym).first.attributes
          char.stats[s.to_sym] = {:base => stat["base"].to_i, :effective => stat["effective"].to_i}
        end
      
        resistances = (tab_xml/:resistances)
        
        SPELL_SCHOOLS.each do |s|
          resist = (resistances/s.to_sym).first.attributes
          char.resistances[s.to_sym] = resist["value"].to_i
        end
        
        # melee stuff
        melee_xml = (tab_xml/:melee)
        
        melee = Hash.new
        
        %w(power hitRating critChance expertise).each do |e|
          melee[e] = (melee_xml/e.to_sym).first.attributes
        end
        
        char.melee[:attack_power] = {:base => melee["power"]["base"].to_i,
                                     :effective => melee["power"]["effective"].to_i}
        char.melee[:crit]         = {:rating => melee["critChance"]["rating"].to_i,
                                     :percent => melee["critChance"]["percent"].to_f}
        char.melee[:hit_rating]   = {:value => melee["hitRating"]["value"].to_i,
                                     :inc_percent => melee["hitRating"]["increasedHitPercent"].to_f}
        char.melee[:expertise]    = {:value => melee["expertise"]["value"].to_i,
                                     :rating => melee["expertise"]["rating"].to_i}
        
        # ranged stuff
        ranged_xml = (tab_xml/:ranged)
        ranged     = Hash.new
        
        %w(power hitRating critChance).each do |e|
          ranged[e] = (ranged_xml/e.to_sym).first.attributes
        end
        
        char.ranged[:attack_power] = {:base => ranged["power"]["base"].to_i,
                                      :effective => ranged["power"]["effective"].to_i}
        char.ranged[:crit]         = {:rating => ranged["critChance"]["rating"].to_i,
                                      :percent => ranged["critChance"]["percent"].to_f}
        char.ranged[:hit_rating]   = {:value => ranged["hitRating"]["value"].to_i,
                                      :inc_percent => ranged["hitRating"]["increasedHitPercent"].to_f}
        
        # spell stuff
        spell_xml = (tab_xml/:spell)
        
        spell_damage_xml = (spell_xml/:bonusDamage)
        spell_damage     = Hash.new
        
        char.schools.each do |e|
          spell_damage[e.to_sym] = (spell_damage_xml/e.to_sym).first.attributes["value"].to_i
        end
        
        char.spell[:damage] = spell_damage

        healing = (spell_xml/:bonusHealing).first.attributes
        char.spell[:healing] = healing["value"].to_i
        
        hit_rating = (spell_xml/:hitRating).first.attributes
        char.spell[:hit_rating] = {:value => hit_rating["value"].to_i,
                                   :inc_percent => hit_rating["increasedHitPercent"].to_f}
        
        spell_crit_xml = (spell_xml/:critChance)
        char.spell[:crit] = {:rating => spell_crit_xml.first.attributes["rating"].to_i, :schools => Hash.new}
        
        char.schools.each do |e|
          char.spell[:crit][:schools][e.to_sym] = (spell_crit_xml/e.to_sym).first.attributes["percent"].to_f
        end
        
        penetration = (spell_xml/:penetration).first.attributes
        char.spell[:penetration] = penetration["value"].to_i
        
        # defense stuff
        defenses_xml = (tab_xml/:defenses)
        defenses     = Hash.new
        
        %w(armor defense resilience).each do |e|
          defenses[e] = (defenses_xml/e.to_sym).first.attributes
        end
        
        char.defenses[:armor] = {:base      => defenses["armor"]["base"].to_i,
                                 :effective => defenses["armor"]["effective"].to_i,
                                 :percent   => defenses["armor"]["percent"].to_f}
                                  
        char.defenses[:defense] = {:value       => defenses["defense"]["value"].to_f,
                                   :plus_def    => defenses["defense"]["plusDefense"].to_i,
                                   :rating      => defenses["defense"]["rating"].to_i,
                                   :inc_percent => defenses["defense"]["increasePercent"].to_f,
                                   :dec_percent => defenses["defense"]["decreasePercent"].to_f}
        
        char.defenses[:resilience] = {:value       => defenses["resilience"]["value"].to_i,
                                      :hit_percent => defenses["resilience"]["hitPercent"].to_f,
                                      :dmg_percent => defenses["resilience"]["damagePercent"].to_f}
        
        %w(dodge parry block).each do |e|
          stat = (defenses_xml/e.to_sym).first.attributes
          char.defenses[e.to_sym] = {:rating  => stat["rating"].to_i,
                                     :percent => stat["percent"].to_f}
        end
        
        # arena teams
        
        teams_xml = (xml/:characterInfo/:character/:arenaTeams/:arenaTeam)
        teams_xml.each do |team|
          team_obj = ArenaTeam::parse_hash(team.attributes)
        
          members_xml = (team/:members/:character)
          members_xml.each do |member|
            member_char = Object.const_get(member.attributes["class"])::parse_hash(member.attributes)
            member_char.realm  = char.realm
            member_char.region = char.region
            
            team_obj.members << member_char
          end
          
          char.arena_teams[team_obj.type] = team_obj
        end
        
        # items
        
        items_xml = (tab_xml/:items/:item)
        
        char.items = Array.new
        
        items_xml.each do |i|
          item = i.attributes
          
          char.items << Item.new(item["id"], item["slot"])
        end
        
        char.check_gear
        
        return char
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
          characters << Object.const_get(e.attributes["class"])::parse_hash(e.attributes)
        end
        
        characters.map { |c| c.region = @region }
        
        return characters
    end
  end
end

class Item
  attr_reader :armory_id, :slot
  
  def initialize(armory_id, slot)
    @armory_id = armory_id.to_i
    @slot = slot.to_i
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