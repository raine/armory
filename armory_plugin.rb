require '~/armory'

class ArmoryPlugin < Plugin
  def search(m, params)
    pp params # debug
    
    result = Armory.new(:us).search(:character, params[:name])
    pp result
    
    
  end
end

plugin = ArmoryPlugin.new
plugin.map "s :name [*str]", :action => 'search', :requirements => {:name => %r{^[A-Za-z]+$}}