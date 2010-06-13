module Termtter::Client
  config.plugins.easy_post.set_default :shortest_message, 15
  register_hook(:easy_post, :point => :command_not_found) do |text|
    if config.confirm && text.length > config.plugins.easy_post.shortest_message
      execute("update #{text}")
    else
      raise Termtter::CommandNotFound, text
    end  
  end
end
