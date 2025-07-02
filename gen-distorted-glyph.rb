#!/usr/bin/env ruby

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
    :horiAdvance,  :long,

    :vertBearingX, :long,
    :vertBearingY, :long,
    :vertAdvance,  :long
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
class FT_Size_Metrics < FFI::Struct
  layout(
    :x_ppem,       :ushort,
    :y_ppem,       :ushort,
    :x_scale,      :long,
    :y_scale,      :long,
    :ascender,     :long,
    :descender,    :long,
    :height,       :long,
    :max_advance,  :long
  )
end
class FT_SizeRec < FFI::Struct
  layout(
    :face, :pointer,
    :generic, [:pointer, 2],
    :metrics, FT_Size_Metrics
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

    :glyph,        :pointer,
    :size,         :pointer
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
  "aa" => false,
  "utf8" => "A",
  "uhex" => nil,
  "seed" => 0xDEADBEEF,
  "mesh" => 1,
  "width" => 0,
  "height" => 32
}
require "getOpts.rb"
if (Opts["uhex"] != nil)
  Opts["uhex"] = Opts.uhex.gsub(/^[Uu]\+/, "").hex()
elsif (Opts["utf8"] != nil)
  Opts["uhex"] = Opts["utf8"].split("").first.encode("ucs-4be").unpack("N").first
end

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
p ft_face_ptr.read_pointer()

# === SET PIXEL SIZE ===
ft_err = FreeType::C.FT_Set_Pixel_Sizes(ft_face, Opts.width, Opts.height)
raise "FT_Set_Pixel_Sizes() failed" unless ft_err == 0

ft_size = FT_SizeRec.new(ft_face[:size])
p ft_size[:face]

ft_metric = ft_size[:metrics]
printf("x_ppem=0x%x\n", ft_metric[:x_ppem])
printf("y_ppem=0x%x\n", ft_metric[:y_ppem])
printf("ascender=0x%016x\n", ft_metric[:ascender])
printf("descender=0x%016x\n", ft_metric[:descender])
printf("height=0x%x\n", ft_metric[:height])
printf("max_advance=0x%x\n", ft_metric[:max_advance])

# === RENDER GLYPH ===
if (Opts.gid == 0)
  Opts.gid = FreeType::C.FT_Get_Char_Index(ft_face, Opts.uhex)
end
ft_err = FreeType::C.FT_Load_Glyph(ft_face, Opts.gid, FreeType::C::FT_LOAD_RENDER)
raise "FT_Load_Glyph() failed" unless ft_err == 0

ft_glyphslot_ptr = ft_face[:glyph]
ft_glyphslot = FT_GlyphSlotRec.new(ft_glyphslot_ptr)

ft_err = FreeType::C.FT_Render_Glyph(ft_glyphslot_ptr, 0)
raise "FT_Render_Glyph() failed" unless ft_err == 0
ft_bitmap = ft_glyphslot[:bitmap]

# === EXTRACT BITMAP DATA ===
glyph_width  = ft_bitmap[:width]
glyph_height = ft_bitmap[:rows]
glyph_advance_to_baseline  = ft_glyphslot[:bitmap_top]
glyph_left_bearing = ft_glyphslot[:bitmap_left]

p ["Opts.width:", Opts.width]
p ["Opts.height:", Opts.height]
p ["bitmap_width:", glyph_width]
p ["bitmap_height:", glyph_height]
p ["advance_to_baseline:", glyph_advance_to_baseline]
p ["bearing_left:", glyph_left_bearing]


ft_pixel_buffer_ptr = ft_bitmap[:buffer]
nbytes_row = ft_bitmap[:pitch]
nbytes_buffer = nbytes_row * glyph_height

arr_pixels = ft_pixel_buffer_ptr.read_bytes(nbytes_buffer).unpack("C*")

## === DUMP BITMAP ===
if (Opts.aa)
  (0...(Opts.height - glyph_advance_to_baseline)).to_a().each do |iy|
    puts(" " * (glyph_left_bearing + glyph_width))
  end

  (0...glyph_height).to_a().each do |iy|
    line = [ " " * glyph_left_bearing ]
    (0...glyph_width).to_a().each do |ix|
      pxl = arr_pixels[(iy * nbytes_row) + ix]
      if (pxl == nil)
        break
      elsif (pxl > 0)
        line << "#"
      else
        line << " "
      end
    end
    printf("%s\n", line.join(""))
  end

  (0...(glyph_advance_to_baseline - glyph_height)).to_a().each do |iy|
    puts(" " * (glyph_left_bearing + glyph_width))
  end


  baseline_y = 0
  bitmap_bottom = ft_glyphslot[:bitmap_top] - ft_bitmap[:rows]
  descender_px = ft_metric[:descender] >> 6

  space_under_baseline = bitmap_bottom - descender_px
  (0...space_under_baseline).to_a().each do |iy|
    puts(" " * (glyph_left_bearing + glyph_width))
  end

end

# === CREATE IMAGE ===
require 'rmagick'
magick_image = Magick::Image.new(glyph_width, glyph_height)
magick_image.background_color = "white"
arr_pixels_16bit = arr_pixels.map{|v| v * 257}
magick_image.import_pixels(0, 0, glyph_width, glyph_height, 'I', arr_pixels_16bit, Magick::ShortPixel)
magick_image = magick_image.negate

# === DISTORT ===
require "./xorshift32.rb"
xorshift32 = XorShift32.new(Opts.a, Opts.b, Opts.c, Opts.seed)
points1 = []
points2 = []
(1..Opts.mesh).each do |iy|
  src_y = glyph_height * iy / Opts.mesh
  (1..Opts.mesh).each do |ix|
    src_x = glyph_width * ix / Opts.mesh
    dx1 = ((xorshift32.next() & 0x1F) - 0xF) * Opts.strength / 0x1F
    dy1 = ((xorshift32.next() & 0x1F) - 0xF) * Opts.strength / 0x1F
    dx2 = ((xorshift32.next() & 0x1F) - 0xF) * Opts.strength / 0x1F
    dy2 = ((xorshift32.next() & 0x1F) - 0xF) * Opts.strength / 0x1F
    dst1_x = src_x + dx1
    dst1_y = src_y + dy1
    dst2_x = src_x + dx2
    dst2_y = src_y + dy2
    points1 << src_x
    points1 << src_y
    points2 << src_x
    points2 << src_y
    points1 << dst1_x
    points1 << dst1_y
    points2 << dst2_x
    points2 << dst2_y
  end
end
magick_image_distorted1 = magick_image.distort(Magick::ShepardsDistortion, points1, true)
magick_image_distorted2 = magick_image.distort(Magick::ShepardsDistortion, points2, true)

# === SAVE IMAGE ===
img_orig = magick_image # .transparent("white")
img_dist1 = magick_image_distorted1 # .transparent("white")
img_dist2 = magick_image_distorted2 # .transparent("white")
img_mixed = Magick::Image.new(img_orig.columns, img_orig.rows)

def decr(v, lmt, s = 2.0)
  if (v < lmt)
    return [lmt - ((lmt - v) * s), 0].max
  else
    return v
  end
end


pxls_dist1 = img_dist1.get_pixels(0, 0, img_dist1.columns, img_dist1.rows)
pxls_dist2 = img_dist2.get_pixels(0, 0, img_dist2.columns, img_dist2.rows)
pxls_mixed = pxls_dist1.zip(pxls_dist2).map{|pxl_dist1, pxl_dist2|
  fi_dist1 = pxl_dist1.intensity * 1.0 / Magick::QuantumRange
  fi_dist2 = pxl_dist2.intensity * 1.0 / Magick::QuantumRange

  if (fi_dist1 < 1 || fi_dist2 < 1)
    fi_dist1 = fi_dist1 * 0.9
    fi_dist2 = fi_dist2 * 0.9
  end

  r =  fi_dist1 * Magick::QuantumRange
  g =  fi_dist2 * Magick::QuantumRange
  b =  fi_dist1 * fi_dist2 * Magick::QuantumRange
  pxl_mixed = Magick::Pixel.new(r, g, b)
  pxl_mixed
}
img_mixed.store_pixels(0, 0, img_mixed.columns, img_mixed.rows, pxls_mixed)

img_mixed.write(Opts.output)

puts "Saved rasterized glyph ##{Opts.gid} to #{Opts.output}"
