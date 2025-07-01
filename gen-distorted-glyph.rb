#!/usr/bin/env ruby

class XorShift32
  attr_accessor(:a, :b, :c, :v)
  def initialize(a_, b_, c_, v_)
    self.a = a_
    self.b = b_
    self.c = c_
    self.v = v_
  end

  def next()
    _v = self.v
    _v = _v ^ ((_v << self.a) & 0xFFFFFFFF)
    _v = _v ^ ((_v >> self.b) & 0xFFFFFFFF)
    _v = _v ^ ((_v << self.c) & 0xFFFFFFFF)
    self.v = _v
    return v
  end
end

require 'freetype'
require 'freetype/c'
class FT_Vector < FFI::Struct
  layout(
    :x, :long,
    :y, :long
  )
end
class FT_BBox < FFI::Struct
  layout(
    :xMin, :long,
    :yMin, :long,
    :xMax, :long,
    :yMax, :long
  )
end
class FT_Glyph_Metrics < FFI::Struct
  layout(
    :width, :long,
    :height, :long,

    :horiBearingX, :long,
    :horiBearingY, :long,
    :horiAdvance, :long,

    :vertBearingX, :long,
    :vertBearingY, :long,
    :vertAdvance, :long
  )
end
class FT_Bitmap < FFI::Struct
  layout(
    :rows,         :uint,
    :width,        :uint,
    :pitch,        :int,
    :buffer,       :pointer,
    :num_grays,    :short,
    :pixel_mode,   :uchar,
    :palette_mode, :uchar,
    :palette,      :pointer
  )
end
class FT_GlyphSlotRec < FFI::Struct
  layout(
    :library,     :pointer,
    :face,        :pointer,
    :next,        :pointer,
    :glyph_index, :uint,
    :generic,      [:pointer, 2],

    :metrics,           FT_Glyph_Metrics,
    :linearHoriAdvance, :long,
    :linearVertAdvance, :long,
    :advance,           FT_Vector,

    :format,      :uint, # 4-letter

    :bitmap,      FT_Bitmap,
    :bitmap_left, :int,
    :bitmap_top,  :int
  )
end
class FT_FaceRec < FFI::Struct
  layout(
    :num_faces,   :long,
    :face_index,  :long,

    :face_flags,  :long,
    :style_flags, :long,

    :num_glyphs,  :long,

    :family_name, :pointer,
    :style_name,  :pointer,

    :num_fixed_sizes, :int,
    :available_sizes, :pointer,

    :num_charmaps, :int,
    :charmaps,     :pointer,

    :generic,      [:pointer, 2],

    :bbox,         FT_BBox,
    :units_per_EM, :ushort,
    :ascender,     :short,
    :descender,    :short,
    :height,       :short,

    :max_advance_width,  :short,
    :max_advance_height, :short,

    :underline_position,  :short,
    :underline_thickness, :short,

    :glyph,        :pointer
  )
end

module FreeType::C
  extend FFI::Library
  ffi_lib "freetype"

  attach_function :FT_Load_Glyph, [:pointer, :uint, :int], :int
  attach_function :FT_Set_Pixel_Sizes, [:pointer, :uint, :uint], :int
  attach_function :FT_Render_Glyph, [:pointer, :int], :int
end

Opts = {
  "a" => 3,
  "b" => 1,
  "c" => 14,
  "gid" => 0,
  "ucs" => 0x41, # 'A'
  "seed" => 0xDEADBEEF,
  "mesh" => 1,
  "width" => 0,
  "height" => 32
}
require "getOpts.rb"

# === INITIALIZE FREETYPE ===
ft_lib_ptr = FFI::MemoryPointer.new(:pointer)
ft_err = FreeType::C.FT_Init_FreeType(ft_lib_ptr)
raise "FT_Init_FreeType() failed" unless ft_err == 0
ft_lib = ft_lib_ptr.read_pointer()

# === INITIALIZE FREETYPE ===
ft_face_ptr = FFI::MemoryPointer.new(:pointer)
ft_err = FreeType::C.FT_New_Face(ft_lib, Opts.font, 0, ft_face_ptr)
raise "FT_New_Face() failed" unless ft_err == 0
ft_face = FT_FaceRec.new(ft_face_ptr.read_pointer())

p ft_face[:num_faces]
p ft_face[:face_index]

# === SET PIXEL SIZE ===
ft_err = FreeType::C.FT_Set_Pixel_Sizes(ft_face, Opts.width, Opts.height)
raise "FT_Set_Pixel_Sizes() failed" unless ft_err == 0

# === RENDER GLYPH ===
if (Opts.gid == 0 && Opts.ucs != 0)
  Opts.gid = FreeType::C.FT_Get_Char_Index(ft_face, Opts.ucs)
end
ft_err = FreeType::C.FT_Load_Glyph(ft_face, Opts.gid, FreeType::C::FT_LOAD_RENDER)
raise "FT_Load_Glyph() failed" unless ft_err == 0
p ft_face[:num_glyphs]
p ft_face[:underline_position]
p ft_face[:underline_thickness]
p Opts.gid

ft_glyphslot_ptr = ft_face[:glyph]
ft_glyphslot = FT_GlyphSlotRec.new(ft_glyphslot_ptr)

p ["original library", ft_lib]
p ["library in glyph slot", ft_glyphslot[:library]]
p ft_face_ptr.read_pointer()
p ft_glyphslot[:face]

p ft_glyphslot[:glyph_index]
ft_err = FreeType::C.FT_Render_Glyph(ft_glyphslot_ptr, 0)
raise "FT_Render_Glyph() failed" unless ft_err == 0
ft_bitmap = ft_glyphslot[:bitmap]

# === EXTRACT BITMAP DATA ===
glyph_width  = ft_bitmap[:width]
glyph_height = ft_bitmap[:rows]
p [glyph_width, glyph_height]

ft_pixel_buffer_ptr = ft_bitmap[:buffer]
nbytes_row = ft_bitmap[:pitch]
nbytes_buffer = nbytes_row * glyph_height

arr_pixels = ft_pixel_buffer_ptr.read_bytes(nbytes_buffer).unpack("C*")

## === DUMP BITMAP ===
#(0..glyph_height).to_a().each do |iy|
#  line = Array.new()
#  (0..glyph_width).to_a().each do |ix|
#    pxl = arr_pixels[(iy * nbytes_row) + ix]
#    if (pxl == nil)
#      break
#    elsif (pxl > 0)
#      line << "#"
#    else
#      line << " "
#    end
#  end
#  printf("%s\n", line.join(""))
#end

# === CREATE IMAGE ===
require 'rmagick'
magick_image = Magick::Image.new(glyph_width, glyph_height)
magick_image.background_color = "white"
arr_pixels_16bit = arr_pixels.map{|v| v * 257}
magick_image.import_pixels(0, 0, glyph_width, glyph_height, 'I', arr_pixels_16bit, Magick::ShortPixel)
magick_image = magick_image.negate

# === DISTORT ===
xorshift32 = XorShift32.new(Opts.a, Opts.b, Opts.c, Opts.seed)
points = []
(1..Opts.mesh).each do |iy|
  src_y = glyph_height * iy / Opts.mesh
  (1..Opts.mesh).each do |ix|
    src_x = glyph_width * ix / Opts.mesh
    dx = ((xorshift32.next() & 0x1F) - 0xF) * Opts.strength / 0xF
    dy = ((xorshift32.next() & 0x1F) - 0xF) * Opts.strength / 0xF
    dst_x = src_x + dx
    dst_y = src_y + dy
    p [dx, dy]
    points << src_x
    points << src_y
    points << dst_x
    points << dst_y
  end
end
p points
#magick_image_distorted = magick_image.distort(Magick::BilinearDistortion, points, true)
magick_image_distorted = magick_image.distort(Magick::ShepardsDistortion, points, true)
#magick_image_distorted = magick_image.distort(Magick::BilinearDistortion, [
#  0.0, 0.0,   10.0, 10.0,   # top-left
#  99.0, 0.0,  99.0, 0.0,    # top-right
#  99.0, 99.0, 99.0, 99.0,   # bottom-right
#  0.0, 99.0,  0.0, 99.0     # bottom-left
#], true)

# === SAVE IMAGE ===
mask_orig = magick_image.transparent("white")
mask_dist = magick_image_distorted.transparent("white")
magick_image_orig_color = mask_orig.colorize(1.0, 1.0, 1.0, "blue")
magick_image_dist_color = mask_dist.colorize(1.0, 1.0, 1.0, "red")
magick_image_layered = magick_image_orig_color.composite(
   magick_image_dist_color,
   0, 0,
   Magick::OverCompositeOp)
magick_image_distorted.write(Opts.output)

puts "Saved rasterized glyph ##{Opts.gid} to #{Opts.output}"
