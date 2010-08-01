# A class to better represent parts of a Tumblr theme template
class ThemeSnippet < String
  
  # Constants ################################################
  
  PostTypes = ["Text", "Regular", "Photo", "Photoset", "Quote", "Link", "Chat", "Conversation", "Audio", "Video", "Answer"]
  
  # Class methods ############################################
  
  # The regular expression to match a block and its contents
  # matchdata $2 will be the content of the block
  def self.block_regex_pattern_for(block_name)  
    Regexp.new(/\{block:(#{block_name})\}((.|\s)*?)\{\/block:(#{block_name})\}/i)
  end
  
  # Instance methods #########################################
  
  # Scans the whole theme and replaces a variable with the replacement provided
  # OPTIMIZE remove puts statements when not needed anymore
  def replace_variable(var_name, replacement)
    print "Replacing variable {#{var_name}}..."
    if self.gsub!(/\{#{var_name}\}/i, replacement) and replacement.present?
      puts "with '#{replacement}'"
    else
      puts "no match found!"
    end
    
    #TODO handle variable transformations
  end
  
  def strip_variable(var_name)
    self.replace_variable(var_name, '')
  end
  
  # looks for the block named 'block_name'
  # and replaces the whole block with just the content of the block or a provided replacement for this content
  # OPTIMIZE remove puts statements when not needed anymore
  def render_block(block_name, replacement = nil)
    print "Rendering block {block:#{block_name}}..."
    if self.gsub!(ThemeSnippet.block_regex_pattern_for(block_name)) { |match| replacement || $2 }
      puts "found and replaced!"
    else
      puts "no match found!"
    end
  end
  
  # removes a whole block
  # OPTIMIZE remove puts statements when not needed anymore
  def strip_block(block_name)
    print "Stripping block {block:#{block_name}}..."
    if self.gsub!(ThemeSnippet.block_regex_pattern_for(block_name), '')
      puts "removed!"
    else
      puts "no match found!"
    end
  end
  
  # pass in a post_type and the posts template ({block:Posts})
  # will render the block of the post_type and remove all others
  def only_render_block_for_post_type(post_type)
    if post_type == 'Text' and !self.block_exists?(post_type)
      if self.block_exists?('Regular')
        post_type = 'Regular'
      end
    elsif post_type == 'Regular' and !self.block_exists?(post_type)
      if self.block_exists?('Text')
        post_type = 'Text'
      end
    end
    
    if post_type == 'Chat' and !self.block_exists?(post_type)
      if self.block_exists?('Conversation')
        post_type = 'Conversation'
      end
    elsif post_type == 'Conversation' and !self.block_exists?(post_type)
      if self.block_exists?('Chat')
        post_type = 'Chat'
      end
    end
    
    types_to_remove = PostTypes.reject { |type| type == post_type }
    
    types_to_remove.each { |type| self.strip_block(type) }
    
    self.render_block post_type, nil
  end
  
  # returns the contents of the provided block
  def fetch_content_of_block(block_name)
    self.match(ThemeSnippet.block_regex_pattern_for(block_name))
    block_content = $2
  end
  
  def block_exists?(block_name)
    self.match(ThemeSnippet.block_regex_pattern_for(block_name)) ? true : false
  end
  
end