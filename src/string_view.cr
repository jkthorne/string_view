require "benchmark"

# StringView::VERSION = "0.1.0"

class String
  def byte_view(start : Int, count : Int) : StringView
    StringView.new(to_unsafe, start, count)
  end

  def chomp_view
    return StringView.new(to_unsafe, 0, 0) if empty?

    case to_unsafe[bytesize - 1]
    when '\n'
      if bytesize > 1 && to_unsafe[bytesize - 2] === '\r'
        StringView.new(to_unsafe, 0, bytesize - 2)
      else
        StringView.new(to_unsafe, 0, bytesize - 1)
      end
    when '\r'
      StringView.new(to_unsafe, 0, bytesize - 1)
    else
      StringView.new(to_unsafe, 0, bytesize)
    end
  end

  NEWLINE_U8  = '\n'.ord.to_u8
  RETURN_CHAR = '\r'

  def each_line_view(chomp = true, &block : StringView ->) : Nil
    # return if empty?

    offset = 0

    while byte_index = byte_index(NEWLINE_U8, offset)
      count = byte_index - offset + 1

      if str = chomp_view
        count -= 1
        count -= 1 if offset + count > 0 && str[offset + count - 1] === RETURN_CHAR
      end

      yield StringView.new(to_unsafe, offset, count)

      offset = byte_index + 1
    end

    StringView.new(to_unsafe, 0, 0) unless offset == bytesize
  end

  def strip_view
    excess_left = calc_excess_left
    if excess_left == bytesize
      return StringView.new(to_unsafe, 0, 0)
    end

    excess_right = calc_excess_right
    StringView.new(
      to_unsafe,
      excess_left,
      excess_left + excess_right
    )
  end
end

struct StringView
  def initialize(
    @buffer : Pointer(UInt8),
    @start : Int32,
    @size : Int32
  )
  end

  def to_s(io : IO) : Nil
    io.write_string(Bytes.new(@size) { |i|
      (@buffer + i).value.to_u8
    })
  end

  def [](index) : Char
    @buffer[index].unsafe_chr
  end
end

dict = File.open("/usr/share/dict/words", "r").gets_to_end

Benchmark.ips do |x|
  x.report("chomp string") { "string\r\n".chomp }
  x.report("chomp string view") { "string\r\n".chomp_view }
end

haiku = "the first cold shower
even the monkey seems to want
a little coat of straw"

result = nil
Benchmark.ips do |x|
  x.report("each line") { haiku.each_line { |s| result = s } }
  x.report("each line view") { haiku.each_line_view { |s| result = s } }
end

Benchmark.ips do |x|
  x.report("strip goodbye") { "\tgoodbye\r\n".strip }
  x.report("strip goodbye view") { "\tgoodbye\r\n".strip_view }
end
