require '~/armory'

class ArmoryPlugin < Plugin
  def search(m, params)
    pp "asd"
    pp Armory.new(:us).search(:character, "Jakuten")
  end
end

plugin = ArmoryPlugin.new
plugin.map "s *str", :action => 'search'