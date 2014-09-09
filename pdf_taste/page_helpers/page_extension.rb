module PDF
  class Reader
    class Page
      def text_receiver
        receiver = PageTextReceiver.new
        walk(receiver)
        receiver
      end
      
      def width
        @attributes[:MediaBox][2] - @attributes[:MediaBox][0]
      end

      def height
        @attributes[:MediaBox][3] - @attributes[:MediaBox][1]
      end
    end
  end
end