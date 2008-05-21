require '~/armory'

class ArmoryPlugin < Plugin
  def search(m, params)
    pp params # debug
    
    result = Armory.new(:us).search(:character, params[:name])
    pp result
    
    if result.empty?
      m.reply "no results"
      return
    end
    
    res = []
    
    result[0..4].each_with_index do |char, i|
      res << "[#{i}] #{char.class}"
    end
    
    m.reply res.join(", ")
  end
end

plugin = ArmoryPlugin.new
plugin.map "s :name [*str]", :action => 'search', :requirements => {:name => %r{^[A-Za-z]+$}}