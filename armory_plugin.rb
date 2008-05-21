require '~/armory'

class ArmoryPlugin < Plugin
  def search(m, params)
    m.reply "foo"
    pp "asd"
    debug "asdasdasd"
  end
end

plugin = ArmoryPlugin.new
plugin.map "s *str", :action => 'search'