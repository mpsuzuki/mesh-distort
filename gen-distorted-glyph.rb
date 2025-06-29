#!/usr/bin/env ruby

require 'freetype'
require 'freetype/c'
require 'rmagick'

include FreeType::API
include FreeType::C
include Magick

# === CONFIGURATION ===
font_path = './NotoSansMono-Regular.ttf'
gid       = 123  # Replace with your desired glyph index
output    = "glyph_#{gid}.png"

# === INITIALIZE FONT ===
font = FreeType::API::Font.open(font_path)
font.set_char_size(0, 64 * 64, 300, 300)

# === RENDER GLYPH ===
module FreeType::C
  extend FFI::Library
  ffi_lib "freetype"

  attach_function :FT_Load_Glyph, [:pointer, :uint, :int], :int
end

FreeType::C.FT_Load_Glyph(font.face, gid, FreeType::C::FT_LOAD_RENDER)
slot   = font.face[:glyph]
bitmap = slot[:bitmap]

# === EXTRACT BITMAP DATA ===
width  = bitmap[:width]
height = bitmap[:rows]
buffer_ptr = bitmap[:buffer]

if buffer_ptr.null?
  puts "Glyph #{gid} has no bitmap (possibly empty or outline-only)."
  exit
end

pixels = buffer_ptr.read_bytes(width * height).unpack('C*')

# === CREATE IMAGE ===
image = Image.new(width, height)
image.background_color = "white"
image.import_pixels(0, 0, width, height, 'I', pixels)

# === SAVE IMAGE ===
image.write(output)
puts "Saved rasterized glyph ##{gid} to #{output}"
