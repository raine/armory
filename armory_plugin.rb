require '~/armory'

class ArmoryPlugin < Plugin
  def search(m, params)
    m.reply "foo"
    pp Armory.new(:us).search("Jakuten")
  end
end

plugin = ArmoryPlugin.new
plugin.map "s *str", :action => 'search'