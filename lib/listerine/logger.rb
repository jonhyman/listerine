# Logging functions
module Listerine
  class Logger
    DEFAULT = 39
    RED = 31
    GREEN = 32
    YELLOW = 33

    class << self
      def print(text)
        display(text)
      end

      def default(text, print = true)
        print_text(text, print, DEFAULT)
      end

      def error(text, print = true)
        print_text(text, print, RED)
      end

      def success(text, print = true)
        print_text(text, print, GREEN)
      end

      def warn(text, print = true)
        print_text(text, print, YELLOW)
      end

      private
      def print_text(text, print, color)
        str = colorize(text, color)
        print ? display(str) : str
      end

      def display(str)
        puts(str)
      end

      def colorize(text, color_code)
        "\e[#{color_code}m#{text}\e[0m"
      end
    end
  end
end
