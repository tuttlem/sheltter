
require 'curses'

class ScrollerWindow

   def initialize(height, width, top, left)
    #  @win_border = Curses::Window.new(height, width, top, left)
      @win_content = Curses::Window.new(height, width, top, left)

   #   @win_border.box('|', '-')
      @win_content.scrollok(true)
      @win_content.idlok(true)
   end

   def println(str)
      @win_content.addstr(str)

      if @win_content.cury == (@win_content.maxy - 1) then
         @win_content.scroll
         @win_content.setpos(@win_content.maxy - 1, 0)
      else
         @win_content.setpos(@win_content.cury + 1, 0)
      end

      self.refresh
   end

   def refresh
      @win_content.refresh
    #  @win_border.refresh
   end

   def window
      @win_content
   end

   def close
      @win_content.close
 #     @win_border.close
   end
end
