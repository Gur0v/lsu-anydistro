#!/usr/bin/env ruby

require 'open3'

DT_INIT       = 12
DT_FINI       = 13
DT_INIT_ARRAY = 25
DT_FINI_ARRAY = 26

def to_number(slice)
  case slice.length
    when 8 then slice.unpack('Q<')[0]
    when 4 then slice.unpack('L<')[0]
    else
      raise
  end
end

def to_slice(number, wordsize)
  case wordsize
    when 8 then [number].pack('Q<')
    when 4 then [number].pack('L<')
    else
      raise
  end
end

def read_dynamic_section(obj, section_offset, wordsize)
  entries = []

  i = 0
  while true
    pos = section_offset + wordsize * 2 * i
    raise 'Truncated dynamic section' if pos + wordsize * 2 > obj.bytesize
    tag = to_number(obj[ pos            ...(pos + wordsize    )])
    val = to_number(obj[(pos + wordsize)...(pos + wordsize * 2)])

    entries << {offset: pos, tag: tag, val: val}

    break if tag == 0

    i += 1
  end

  entries
end

def wwrite(obj, offset, number, wordsize)
  pos = offset
  for char in to_slice(number, wordsize).chars
    obj[pos] = char
    pos += 1
  end
end

def patch_init(path, out_path)

  headers, status = Open3.capture2('readelf', '--headers', '--wide', File.expand_path(path))
  raise "readelf failed for #{path}" unless status.success?

  elf_class = headers.match(/Class:\s+(ELF32|ELF64)/)
  dynamic_section = headers.match(/\.dynamic\s+DYNAMIC\s+\h+\s+(\h+)/)
  raise 'Missing ELF class or dynamic section' unless elf_class && dynamic_section
  raise 'Unsupported ELF byte order' unless headers.match?(/Data:\s+2's complement, little endian/)
  wordsize = elf_class[1] == 'ELF64' ? 8 : 4
  dynamic_section_offset = dynamic_section[1].to_i(16)

  obj = IO.binread(path)

  for entry in read_dynamic_section(obj, dynamic_section_offset, wordsize)
    case entry[:tag]
      when DT_INIT, DT_INIT_ARRAY #, DT_FINI, DT_FINI_ARRAY
        wwrite(obj, entry[:offset], 0x42420000 + entry[:tag], wordsize)
    end
  end

  IO.binwrite(out_path, obj)
end

abort "Usage: #{$0} INPUT OUTPUT" unless ARGV.length == 2
patch_init(ARGV[0], ARGV[1])
