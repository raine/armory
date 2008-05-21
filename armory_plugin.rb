require '~/armory'

class ArmoryPlugin < Plugin
  def search(m, params)
    pp Armory.new(:eu).search(:character, params[:name])
  end
end

plugin = ArmoryPlugin.new
plugin.map "s :name [*str]", :action => 'search'