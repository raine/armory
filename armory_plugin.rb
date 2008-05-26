# TO DO
# - [16:32:05] <        rane> | ,s Tun tauren druid
#   [16:32:07] <     jakubot> | <2> [!1|100%] 70 Tauren Druid (Magtheridon), [!2|100%] 70 Tauren Druid <> (Marécage de Zangar) 
# 
# - S3: 5/5 etc.

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
    case topic
    when 'commands'
      "Commands: c(haracter), s(earch), last | 'help armory <command>' for more info on specific command"
    when 'c'
      "Usage: c [<region>] <character name> [<realm>] [<keywords>] | Keywords: 2|3|5vs2|3|5 | Examples: 'c us serennia cho'gall 2on2'"
    when 's'
      "Usage: s [<region>] <character name> [<keywords>] | Keywords can be attributes like 'tauren', 'gnome' or '<Guild>' | Examples: 's eu athene hunter blood elf', 's punisher orc warrior' | Upon getting search results you can get armory profiles of those character using '!<result id>'"
    when 'last'
      "Usage: last [<keywords>] | Keywords: 2|3|5vs2|3|5 | Used to access latest armory profile that has been fetched from armory"
    else
      "Armory plugin -- 'help armory commands' for list of commands"
    end
  end
  
  def character_action(m, params)
    name = params[:name]
    
    if params[:region].nil? && !@bot.config['armory.region']
      m.reply "default region not set, specify region pls"
      return
    elsif params[:region]
      region = params[:region].to_sym
    else
      region = @bot.config['armory.region'].to_sym
    end
      
    if params[:realm].empty? && !@bot.config['armory.realm']
      m.reply "default realm not set, specify realm pls"
      return
    elsif !params[:realm].empty?
      realm = params[:realm].to_s
    else
      realm = @bot.config['armory.realm']
    end
    
    character(name, realm, region, m, params)
  end
  
  def character(name, realm, region, m, params=nil)
    # check cache and stuff
    
    if @bot.config['armory.cache'] && cached = @cache.find_character(name, realm, region)
      pp "using cache "
      char = cached
    else
      begin
        char = Armory.new(region).character(name, realm)
      rescue => e
        m.reply "error: #{e.message}"
      end
      
      @cache.save_character(char)
    end
    
    source = m.replyto.to_s
    
    @temp[source] = Hash.new unless @temp[source]
    @temp[source][:last] = char
    
    
    if params and !params[:keywords].empty?
      pp params
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
      end
    else
      m.reply output(char)
    end
  end
  
  def parse_keywords(keywords)
    keywords.gsub!(/:/,"")
    
    case keywords  
    when /(2(?:on|v|vs)2|3(?:on|v|vs)3|5(?:on|v|vs)5)/
    # 2[on|vs/v]2 etc.
      return $1.gsub(/(\d).*?\d/) { |match| $1+'vs'+$1 }.to_sym
    end
  end
  
  def last(m, params)
    source = m.replyto.to_s
    
    pp params
    
    return unless @temp[source][:last]
    
    char = @temp[source][:last]
    
    character(char.name, char.realm, char.region, m, params)
  end
  
  def search(m, params)
    if params[:region].nil?
      region = @bot.config['armory.region'].to_sym
    else
      region = params[:region].to_sym
    end
    
    result = Armory.new(region).search(:character, params[:name])
      
    # check for additional keywords like race or class
    unless params[:keywords].empty?      
      str = params[:keywords].to_s
      
      keywords = {}
      
      keywords[:race]  = $1 if str =~ /(#{RACES.join("|")})/i
      keywords[:class] = $1 if str =~ /(#{CLASSES.join("|")})/i
      keywords[:guild] = $1 if str =~ /<([A-Za-z\-\s]+)>/i
      
      if keywords[:race]
        result.delete_if { |c| c.race.to_s.downcase != keywords[:race].downcase }
      end
      
      if keywords[:class]
        result.delete_if { |c| c.char_class.to_s.downcase != keywords[:class].downcase }
      end
      
      if keywords[:guild]
        result.delete_if { |c| c.guild.to_s.downcase != keywords[:guild].downcase }
      end
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

      str  = "[#{Bold}!#{i+1}#{Bold}|#{char.relevance}%] #{char.level} #{char.race} #{char.char_class.to_s.capitalize}"
      str << " <#{char.guild}>" unless char.guild.nil?
      str << " (#{char.realm})"
      
      res << str
    end
    
    m.reply "<#{result.size}> "+res.join(", ")
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
                  searched_char.region, m, params)
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
  
  def output(obj)
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
          :points => Utilities::rating_to_points(team.rating)[team.type]
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
              :class => m.char_class.to_s.capitalize,
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
        
        talent_str = char.talents.map{ |t| t[:points]}.join("/")
        
        # form the reply string

        str << char.title[:prefix]+char.name+char.title[:suffix]
        str << ' <'+char.guild+'>' unless char.guild.nil? || char.guild.empty?
        
        str << _(", %{level} %{race} %{class}") % {
          :level => char.level,
          :race  => char.race.to_s.cew,
          :class => char.char_class.to_s.capitalize
        }
        
        str << _(" (%{talents}, %{spec})") % {
          :talents => talent_str,
          :spec => char.spec.to_s.cew
        }

        # hp and mana
        str << _(" | H: %{health}") % {
          :health => colorize(char.stats[:health], :red)
        }
        
        str << _(" M: %{mana}") % {
          :mana => colorize(char.stats[:mana], :blue)
        } if char.stats[:mana]
        
        str << _(" Resilience: %{resi} (-%{hit}%)") % {
          :resi => colorize(char.defenses[:resilience][:value], :yellow),
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
            if char.spell_schools.values.uniq.size > 1
              # spell schools relevant to the class have different damage bonuses
              # so they are shown individually
          
              char.spell_schools.each do |s,d|
                str << _(" +%{school}: %{damage}") % {
                  :school => s.to_s.capitalize,
                  :damage => d
                }
              end
            else
              str << _(" +Spell Damage: %{damage}") % {
                :damage => char.spell_schools.values.first
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
          }
          
        # hunter's ranged stuff
        elsif char.char_class == :hunter
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
          }
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
        
        # PVP
        # arena teams
        
        str << " |"
        unless char.arena_teams.empty?
          
          teams = [2, 3, 5].map do |s|
            if char.arena_teams[s]
              char.arena_teams[s].rating
            else
              "-"
            end
          end.join("/")
          
          str << _(" Arena: (%{teams})") % {
            :teams => teams
          }
          
        end
        
        str << _(" Points: %{ap}") % {
          :ap => char.pvp[:arena_points]
        } if char.pvp[:arena_points] > 0
        
        str << _(" LHKs: %{lhk}") % {
          :lhk => char.pvp[:lifetime_kills]
        } if char.pvp[:lifetime_kills] > 0
        
    end
    return str
  end
  
  def colorize(str, color)
    Irc.color(color)+str.to_s+Irc.color()
  end
end

plugin = ArmoryPlugin.new
plugin.map "s [:region] :name [*keywords]",
  :action => 'search',
  :requirements => {:name => %r{^[A-Za-z]+$}, 
                    :region => %r{eu|us}}
plugin.map "c [:region] :name [*realm] [*keywords]",
  :action => 'character_action',
  :requirements => {:name => %r{^[A-Za-z]+$},
                    :region => %r{eu|us},
                    :realm => %r{['A-Za-z\-\s]+}}

plugin.map "last [*keywords]",
  :action => 'last'