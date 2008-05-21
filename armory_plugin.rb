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
      str = ""
      str << "[#{i+1}] #{char.class.to_s.downcase}"
      str << " <#{char.guild}>" unless char.guild.nil?
      
      res << str
    end
    
    m.reply res.join(", ")
  end
end

plugin = ArmoryPlugin.new
plugin.map "s :name [*str]", :action => 'search', :requirements => {:name => %r{^[A-Za-z]+$}}