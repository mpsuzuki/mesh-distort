#!/usr/bin/env ruby

require 'freetype'
require 'freetype/c'
require 'rmagick'

Opts = {
  "dpi" => 64
}
require "getOpts.rb"

# === INITIALIZE FONT ===
ft_font = FreeType::API::Font.open(Opts.font)
ft_font.set_char_size(0, Opts.dpi * Opts.dpi, Opts.width, Opts.height)

# === RENDER GLYPH ===
module FreeType::C
  extend FFI::Library
  ffi_lib "freetype"

  attach_function :FT_Load_Glyph, [:pointer, :uint, :int], :int
end

FreeType::C.FT_Load_Glyph(ft_font.face, Opts.gid, FreeType::C::FT_LOAD_RENDER)
ft_slot   = ft_font.face[:glyph]
ft_bitmap = ft_slot[:bitmap]

# === EXTRACT BITMAP DATA ===
glyph_width  = ft_bitmap[:width]
glyph_height = ft_bitmap[:rows]
glyph_buffer_ptr = ft_bitmap[:buffer]

if glyph_buffer_ptr.null?
  puts "Glyph #{gid} has no bitmap (possibly empty or outline-only)."
  exit
end

glyph_pixels = glyph_buffer_ptr.read_bytes(glyph_width * glyph_height).unpack('C*')

# === CREATE IMAGE ===
magick_image = Magick::Image.new(glyph_width, glyph_height)
magick_image.background_color = "white"
magick_image.import_pixels(0, 0, glyph_width, glyph_height, 'I', glyph_pixels)

# === SAVE IMAGE ===
magick_image.write(Opts.output)
puts "Saved rasterized glyph ##{Opts.gid} to #{Opts.output}"
