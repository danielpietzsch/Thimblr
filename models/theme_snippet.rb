class ThemeSnippet < String
  
  # The regular expression to match a block and its contents
  # matchdata $2 will be the content of the block
  def ThemeSnippet.block_regex_pattern_for(block_name)  
    Regexp.new(/\{block:(#{block_name})\}((.|\s)*?)\{\/block:(#{block_name})\}/i)
  end
  
  # Scans the whole theme and replaces a variable with the replacement provided
  def replace_variable(var_name, replacement)
    print "[ThemeSnippet] Replacing variable {#{var_name}}..."
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
  def render_block(block_name, replacement = nil)
    print "[ThemeSnippet] Rendering block {block:#{block_name}}..."
    if self.gsub!(ThemeSnippet.block_regex_pattern_for(block_name)) { |match| replacement || $2 }
      puts "found and replaced!"
    else
      puts "no match found!"
    end
  end
  
  # removes a whole block
  def strip_block(block_name)
    print "[ThemeSnippet] Stripping block {block:#{block_name}}..."
    if self.gsub!(ThemeSnippet.block_regex_pattern_for(block_name), '')
      puts "removed!"
    else
      puts "no match found!"
    end
  end
  
end