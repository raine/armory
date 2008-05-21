require '~/armory'

class ArmoryPlugin < Plugin
  def search(m, params)
    pp params
    #pp Armory.new(:us).search(:character, "Jakuten")
  end
end

plugin = ArmoryPlugin.new
plugin.map ":region *str", :action => 'search', :requirements => { :region => %r|eu|us| }