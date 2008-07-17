# TO DO:
# 
#

require '~/armory'

class ::String
  def cew
    self.split.map { |w| w.capitalize }.join(" ")
  end
end

class ArmoryPlugin < Plugin
  Config.register Config::StringValue.new('armory.region',
    :default => "eu",
    :desc => "Default region")
  
  Config.register Config::StringValue.new('armory.realm',
    :desc => "Default realm")

  Config.register Config::BooleanValue.new('armory.cache',
    :desc => "Cache characters",
    :default => true)

  def initialize
    super
    
    @temp = {}
    
    @cache = CharacterCache.new
  end
  
  def help(plugin, topic="")
    url = "http://guaxia.org/jakubot/#"
    keywords = ["2vs2 etc", "talents", "professions", "realm"]
    
    case topic
    when 'commands'
      "Commands: c(haracter), s(earch), last, l(ucky), me, iam, show | 'help armory <command>' for more info on specific command"
    when 'c'
      "Usage: c [<region>] <character name> [<realm>] [<keywords>] | Keywords: #{keywords.map { |e| ":"+e }.join(", ")} | Examples: 'c us serennia cho'gall 2on2' | #{url}c"
    when 's'
      "Usage: s [<region>] <character name> [<keywords>] | Keywords can be attributes like 'tauren', 'gnome', '<Guild>' or a name of a battlegroup | Examples: 's eu athene hunter blood elf', 's punisher orc warrior' | Upon getting search results you can get armory profiles of those characters using '!<result id>' | #{url}s"
    when 'last'
      "Usage: last [<keywords>] | Keywords: #{keywords.join(", ")} | Used to access latest armory profile that has been fetched from armory | #{url}last"
    when 'l'
      "Usage: l [<region>] <character name> [<search keywords>] [<other keyword>] | Search keywords are same that can be used for normal searches. Other Keywords: #{keywords.map { |e| ":"+e }.join(", ")} | Similar to Google's feeling lucky search, returning profile of the most relevant character | Example: 'l serennia gnome warrior :2vs2' would return 2vs2 team info of gnome warrior named Serennia | #{url}l"
    when 'q'
      "Usage: q [<region>] <character name> <bracket> [<keywords>] | Bracket: 2|3|5 | Keywords: see help for 'c'"
    when 'me'
      "Usage: me [<keywords>] | Keywords: #{keywords.join(", ")} | Used to access your own predefined character | #{url}me"
    when 'iam'
      "Usage: iam [<region>] <character name> [<realm>] | Used to set your own character | After setting a character for yourself, the bot will automatically choose your character's region and/or realm as parameter(s) for any command if those parameters have been left out | #{url}iam"
    when 'show'
      "Usage: show <nick> [keyword] | Used to access another user's preset character | #{url}show"
    else
      "Armory plugin -- Commands: c(haracter), s(earch), last, l(ucky), q(uick), me (alias:my), iam, show | 'help armory <command>' for more info on specific command or see http://guaxia.org/jakubot/ for more elaborate help"
    end
  end
  
  def get_realm(m, params)
    if !params[:realm].empty?
      Util::levenshtein_realm(params[:realm].to_s)
    elsif m.source.get_botdata[:armory]
      m.source.get_botdata[:armory][:realm]
    elsif @bot.config['armory.realm']
      @bot.config['armory.realm']
    end
  end
  
  def get_region(m, params)
    if params[:region]
      params[:region].downcase.to_sym
    elsif m.source.get_botdata[:armory]
      m.source.get_botdata[:armory][:region]
    elsif @bot.config['armory.region']
      @bot.config['armory.region'].to_sym
    end
  end

  def character_action(m, params)    
    realm  = get_realm(m, params)
    region = get_region(m, params)
    
    unless realm
      m.reply "specify realm"
      return
    end
    
    unless region
      m.reply "specify region"
      return
    end
    
    name = params[:name]
    character(name, realm, region, m, params)
  end
  
  def character(name, realm, region, m, params=nil, options=nil)
    # check cache and stuff
    
    if @bot.config['armory.cache'] && cached = @cache.find_character(name, realm, region)
      char = cached
    else
      begin
        char = Armory.new(region).character(name, realm)
      rescue Timeout::Error => e
        m.reply "error: timeout :("
      rescue NoCharacterError => e
        m.reply "error: #{e.message} on #{realm.cew}"
      rescue => e
        m.reply "error: #{e.message}"
      end
      
      @cache.save_character(char)
    end
    
    source = m.replyto.to_s
    
    @temp[source] = Hash.new unless @temp[source]
    @temp[source][:last] = char
    
    if params and !params[:keywords].empty?
      keyword = parse_keywords(params[:keywords].to_s)

      case keyword
      when :"2vs2", :"3vs3", :"5vs5"
        bracket = keyword.to_s.split(//).first.to_i
    
        if char.arena_teams[bracket]
          @temp[source][:arena_team] = char.arena_teams[bracket].members            
          m.reply output(char.arena_teams[bracket])
        else
          m.reply "character doesn't have a team in that bracket"
        end
      when :talents, :professions, :realm
        m.reply output(char, keyword)
      end
    else
      m.reply output(char, nil, options)
    end
  end
  
  def parse_keywords(keywords)
    keywords.gsub!(/:/,"")
    
    case keywords  
    when /(2(?:on|v|vs)2|3(?:on|v|vs)3|5(?:on|v|vs)5)/i
      # 2[on|vs/v]2 etc.
      return $1.gsub(/(\d).*?\d/) { |match| $1+'vs'+$1 }.to_sym
    when /talents|spec/i
      # talents
      return :talents
    when /profession|professions|prof|profs/i
      # professions
      return :professions
    when /realm/i
      # realm
      return :realm
    end
  end
  
  def last(m, params)
    source = m.replyto.to_s
    
    return unless @temp[source][:last]
    
    char = @temp[source][:last]
    
    character(char.name, char.realm, char.region, m, params)
  end
  
  def search_action(m, params)
    region = get_region(m, params)
    
    begin
      result = search(region, params)
    rescue => e
      m.reply "error: #{e.message}"
      return
    end
      
    if result.empty?
      m.reply "no results"
      return
    end
    
    # save result
    source = m.replyto.to_s
    
    @temp[source] = Hash.new if @temp[m.replyto.to_s].nil?
    @temp[source][:search] = result
    
    res = []
    result[0..4].each_with_index do |char, i|
      str = String.new
      str << _("[%{b}!%{id}%{b}|%{relevance}%]") % {
        :b  => Bold,
        :id => i+1,
        :relevance => char.relevance
      }
      str << _(" %{level} %{race} %{class}") % {
        :level => char.level,
        :race  => char.race,
        :class => char.class.to_s
      }
      str << _(" <%{guild}>") % {
        :guild => char.guild
      } unless char.guild.nil? or char.guild.empty?
      str << _(" (%{realm})") % {
        :realm => char.realm
      }
      
      res << str
    end
    
    m.reply "<#{result.size}> "+res.join(", ")
  end
  
  def search(region, params)
    # initial result
    result = Armory.new(region).search(:character, params[:name])
    
    # check for additional keywords like race or class
    unless params[:keywords].empty?
      str = params[:keywords].to_s
      
      keywords = {}
      
      # parse keywords
      keywords[:race]        = $1 if str =~ /(#{RACES.join("|")})/i
      keywords[:class]       = $1 if str =~ /(#{CLASSES.join("|")})/i
      keywords[:guild]       = $1 if str =~ /<([A-Za-z\-\s]+)>/i
      keywords[:level]       = $1 if str =~ /(\d{2})/
      keywords[:battlegroup] = $1 if str =~ /(#{BATTLEGROUPS.join("|")})/i
      
      # remove entries that don't match the given keywords
      keywords.each do |keyword, value|
        result.delete_if { |c| c.send(keyword.to_s).to_s.downcase != value.downcase }
      end
    end
    
    return result
  end
  
  # search similar to "I'm feeling lucky" in google
  def lucky(m, params)
    region = get_region(m, params)
    
    result = search(region, params)
    
    if result.empty?
      m.reply "out of luck!"
      return
    end
    
    first = result.first
    
    character(first.name, first.realm, first.region, m, {:keywords => params[:keywords2]}, {:show_realm => true})
  end
  
  def quick(m, params)
    params[:keywords]<<70.to_s
    region = get_region(m, params)
    result = search(region, params)
    
    if result.empty?
      m.reply "no results"
      return
    end

    first = result.first
    
    cached = @cache.find_character(first.name, first.realm, first.region)
    
    char = if cached
      cached
    else
      Armory.new(first.region).character(first.name, first.realm)
    end
    
    @cache.save_character(char)
    
    bracket = params[:bracket].to_i
    
    source = m.replyto.to_s
    @temp[source] = Hash.new unless @temp[source]
    
    if char.arena_teams[bracket]
      team = char.arena_teams[bracket]
      
      @temp[source][:arena_team] = team.members
      m.reply output(team)
      
      team.members.each do |member|
        character(member.name, member.realm, member.region, m)
      end
    else
      m.reply "character found doesn't have team in that bracket"
    end
  end

  def message(m)
    return unless m.message =~ /^(!|%)(\d+)(.*?)$/
    source = m.replyto.to_s
    
    temp_id = $2.to_i
    
    params = {:keywords => $3}
    
    case $1
    when /!/ # search prefix
      return unless @temp[source][:search]
      searched_char = @temp[source][:search][temp_id-1]
      
      if searched_char
        character(searched_char.name,
                  searched_char.realm,
                  searched_char.region, m, params, {:show_realm => true})
      end
    when /%/ # arena team member prefix
      return unless @temp[source][:arena_team]
      
      team_member = @temp[source][:arena_team][temp_id-1]
      
      if team_member
        character(team_member.name,
                  team_member.realm,
                  team_member.region, m, params)
      end
    end
  end
  
  def output(obj, what=nil, options=nil)
    str = String.new
    
    case obj
      when ArenaTeam  
        team = obj

        # team info        
        str << "[#{team.type}on#{team.type}] "
        str << _("%{name}") % {:name => Bold+team.name+Bold}
        str << " | "
        str << _("Rank: %{rank} ") % {:rank => team.rank} unless team.rank.zero?
        str << _("Rating: %{rating} (%{points} pts)") % {
          :rating => team.rating,
          :points => ArenaRating::rating_to_points(team.rating)[team.type]
        }
        str << " | "
        str << _("Won: %{won_season}(%{won_week})") % {
          :won_season  => colorize(team.games[:season][:won], :lime_green),
          :won_week    => colorize(team.games[:week][:won], :lime_green),
        }
        str << _(" Lost: %{lost_season}(%{lost_week})") % {
          :lost_season => colorize(team.games[:season][:lost], :red),
          :lost_week   => colorize(team.games[:week][:lost], :red)
        }
        str << _(" Total: %{total_season}(%{total_week})") % {
          :total_season => team.games[:season][:total],
          :total_week   => team.games[:week][:total],
        }
        
        # members
        unless team.members.empty?
          str << " | Members: "
          
          members = Array.new
          team.members.each_with_index do |m, i|
            member_str = String.new
            member_str << _("[%{b}%%{id}%{b}] ") % { :id => i+1, :b => Bold }
            member_str << _("%{race} %{class} %{name}") % {
              :race  => m.race,
              :class => m.class.to_s,
              :name  => m.name
            }
            
            member_str << _(" (%{won}/%{lost})") % {
              :won   => colorize(m.arena_games_won, :lime_green),
              :lost  => colorize(m.arena_games_lost, :red),
              :total => m.arena_games_total
            }
            members << member_str
          end
          
          str << members.join(", ")
        end
      when Character
        char = obj
        
        if what
          case what
            when :talents
              trees = char.talents.map {|t| t[:points]}.join("/")
              str << _("%{spec} %{class}, %{trees} -- %{url}") % {
                :spec  => char.spec.to_s.cew,
                :class => char.class,
                :trees => trees,
                :url   => char.talents_exact
              }
            when :professions
              str << char.professions.map do |prof|
                "#{prof[:name].to_s.capitalize} #{prof[:value]}/#{prof[:max]}"
              end.join(", ")
            when :realm
              str << _("%{realm} of the %{bg} Battlegroup (%{region})") % {
                :realm => char.realm,
                :bg => char.battlegroup,
                :region => char.region.to_s.upcase
              }
          end
        else
          str << char.title[:prefix]+char.name+char.title[:suffix]
          str << ' <'+char.guild+'>' unless char.guild.nil? || char.guild.empty?
          str << ' ('+char.realm+'-'+char.region.to_s.upcase+')' if options && options[:show_realm]
        
          str << _(", %{level} %{race} %{class}") % {
            :level => char.level,
            :race  => char.race.to_s.cew,
            :class => char.class.to_s
          }
        
          trees = char.talents.map {|t| t[:points]}.join("/")
          str << _(" (%{talents}, %{spec})") % {
            :talents => trees,
            :spec => char.spec.to_s.cew
          }

          # hp and mana
          str << _(" | H: %{health}") % {
            :health => char.stats[:health]
          }
        
          str << _(" M: %{mana}") % {
            :mana => char.stats[:mana]
          } if char.stats[:mana]
        
          str << _(" Resilience: %{resi} (-%{hit}%)") % {
            :resi => char.defenses[:resilience][:value],
            :hit => char.defenses[:resilience][:hit_percent]
          } if char.defenses[:resilience][:value] > 0
        
          str << " |"
        
          # class and spec specific attributes
        
          if char.caster?
            if char.healer?
              str << _(" +Healing: %{healing}") % {
                :healing => char.spell[:healing]
              }
            
              str << _(" +mp5: %{mp5}") % {
                :mp5 => char.spell[:mp5]
              }            
            elsif char.caster?
              if char.spell[:damage].values.uniq.size > 1
                # spell schools relevant to the class have different damage bonuses
                # so they are shown individually
                
                char.spell[:damage].each do |s,d|
                  str << _(" +%{school}: %{damage}") % {
                    :school => s.to_s.capitalize,
                    :damage => d
                  }
                end
              else
                str << _(" +Spell Damage: %{damage}") % {
                  :damage => char.spell[:damage].values.first
                }
              end
              
              # show healing as well for balance druids
              if char.class == Druid
                str << _(" +Healing: %{healing}") % {
                  :healing => char.spell[:healing]
                }
              end              
            end
          
            str << " |"
          
            # spell hit
            str << _(" Hit: %{hit} (%{percent}%)") % {
              :hit     => char.spell[:hit_rating][:value],
              :percent => char.spell[:hit_rating][:inc_percent]
            } if char.spell[:hit_rating][:value] > 0
          
            # spell crit
            str << _(" Crit: %{crit}%") % {
              :crit => char.spell[:crit][:schools].values.first
            } if char.spell[:crit][:schools].values.first > 0
          # hunter's ranged stuff
          elsif char.class == Hunter
            str << _(" RAP: %{rap}") % {
              :rap => char.ranged[:attack_power][:effective]
            }
            str << " |"        
            str << _(" RCrit: %{percent}%") % {
              :percent => char.ranged[:crit][:percent]
            }          
            str << _(" RHit: %{hit} (+%{percent}%)") % {
              :hit     => char.ranged[:hit_rating][:value],
              :percent => char.ranged[:hit_rating][:inc_percent],
            } if char.ranged[:hit_rating][:value] > 0
          
          # tanks
          elsif char.tank?
            str << _(" Defense: %{defense}") % {
              :defense => (char.defenses[:defense][:value]+char.defenses[:defense][:plus_def]).to_i
            }          
            str << _(" Dodge: %{percent}%") % {
              :percent => char.defenses[:dodge][:percent]
            }
          
            if char.class == Warrior or char.class == Paladin
              str << _(" Armor: %{armor} (-%{percent}%)") % {
                :armor   => char.defenses[:armor][:effective],
                :percent => char.defenses[:armor][:percent]
              }
              str << _(" Block: %{percent}%") % {
                :percent => char.defenses[:block][:percent]
              }
              str << _(" Parry: %{percent}%") % {
                :percent => char.defenses[:parry][:percent]
              }
            end
          else
            str << _(" AP: %{ap}") % {
              :ap => char.melee[:attack_power][:effective]
            }
            str << " |"
            str << _(" Crit: %{percent}%") % {
              :percent => char.melee[:crit][:percent]
            }          
            str << _(" Hit: %{hit} (+%{percent}%)") % {
              :hit     => char.melee[:hit_rating][:value],
              :percent => char.melee[:hit_rating][:inc_percent],
            } if char.melee[:hit_rating][:value] > 0
          end
        
          # special gear
        
          unless char.gear.values.map { |e| e.values }.flatten.max.zero?
            str << " | "
          
            gear = []
            prefixes = {:pve => "T", :arena => "S"}
            pieces   = {:pve   => {4=>5,5=>5,6=>8},
                        :arena => {1=>5,2=>5,3=>5, 4=>5}}
          
            char.gear.keys.each do |type|
              char.gear[type].each do |tier, amount|
                gear << _("%{prefix}%{tier}: %{amount}/%{max}") % {
                  :prefix => prefixes[type],
                  :tier   => tier,
                  :amount => amount,
                  :max    => pieces[type][tier]
                } unless amount.zero?
              end
            end
          
          
            str << gear.join(", ")
          end
        
          # PVP
          # arena teams
          
          pvp_substr = ""
          
          unless char.arena_teams.empty?
          
            teams = [2, 3, 5].map do |s|
              if char.arena_teams[s]
                char.arena_teams[s].rating
              else
                "-"
              end
            end.join("/")
          
            pvp_substr << _(" Arena: %{teams}") % {
              :teams => teams
            }
          
          end
        
          pvp_substr << _(" Points: %{ap}") % {
            :ap => char.pvp[:arena_points]
          } if char.pvp[:arena_points] > 0
        
          pvp_substr << _(" LHKs: %{lhk}") % {
            :lhk => char.pvp[:lifetime_kills]
          } if char.pvp[:lifetime_kills] > 0
          
          str << " |" + pvp_substr unless pvp_substr.empty?
          
          # armory url
          str << _(" | %{url}") % {
            :url => char.url
          }
          
        end
    end
    return str
  end
  
  def set_own_character(m, params)
    realm  = get_realm(m, params)
    region = get_region(m, params)
    
    name = params[:name]
    
    m.source.set_botdata('armory.name',   name)
    m.source.set_botdata('armory.realm',  realm)
    m.source.set_botdata('armory.region', region)
    
    m.notify "You are now #{name.capitalize} of the #{realm.cew} (#{region.to_s.upcase})"+
             " | From now on when using the bot, you don't have to enter"+
             " region and/or realm when looking for things on your character's realm,"+
             " for example, you could just do ',c #{name.downcase}'."
  end
  
  def get_own_character(m, params)
    if m.source.get_botdata[:armory]
      char = m.source.get_botdata[:armory]
      character(char[:name], char[:realm], char[:region], m, params, {:show_realm => true})
    else
      m.notify "You don't have a character set, see ´#{@bot.config[:"core.address_prefix"]}help armory iam´ for help"
    end
  end
  
  def get_user_character(m, params)
    if m.server.get_user(params[:nick]).get_botdata[:armory]
      char = m.server.get_user(params[:nick]).get_botdata[:armory]
      character(char[:name], char[:realm], char[:region], m, params, {:show_realm => true})
    else
      m.reply "#{params[:nick]} doesn't have a character set"
    end
  end

  def colorize(str, color)
    Irc.color(color)+str.to_s+Irc.color()
  end
end

REGEX_REGION   = %r{eu|us}i
REGEX_CHARNAME = %r{^[^-\d\s]+$}
REGEX_REALM    = %r{^[^-]['A-Za-z\-\s]+}

plugin = ArmoryPlugin.new

plugin.map "s [:region] :name [*keywords]",
  :action => 'search_action', :requirements => {:name => REGEX_CHARNAME, :region => REGEX_REGION}
plugin.map "c [:region] :name [*realm] [*keywords]",
  :action => 'character_action', :requirements => {:name => REGEX_CHARNAME, :region => REGEX_REGION, :realm  => REGEX_REALM}
plugin.map "last [*keywords]",
  :action => 'last'
plugin.map "l [:region] :name [*keywords] [*keywords2]",
  :action => 'lucky', :requirements => {:name => REGEX_CHARNAME, :region => REGEX_REGION, :keywords2 => %r{^-\w+$}}          
plugin.map "q [:region] :name :bracket [*keywords]",
  :action => 'quick', :requirements => {:name => REGEX_CHARNAME, :region => REGEX_REGION, :bracket => %r{2|3|5}}
plugin.map "me [*keywords]",
  :action => 'get_own_character'
plugin.map "my [*keywords]",
  :action => 'get_own_character'
plugin.map "iam [:region] :name [*realm]",
  :action => 'set_own_character', :requirements => {:name => REGEX_CHARNAME, :region => REGEX_REGION, :realm => REGEX_REALM}
plugin.map "show :nick [*keywords]",
  :action => 'get_user_character', :requirements => {:nick => %r{[^\s]+}}