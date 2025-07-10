#!/usr/bin/env ruby

Opts = {
  "a" => 3,
  "b" => 1,
  "c" => 14,
  "gid" => 0,
  "aa" => false,
  "var-wght" => 0.5,
  "var-wdth" => 0.5,
  "utf8" => "A",
  "uhex" => nil,
  "seed" => "0xDEADBEEF",
  "strength" => 20,
  "noise_subtract" => 20,
  "noise_add" => 0,
  "output" => "glyph.png",
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
if (Opts["seed"] != nil)
  Opts["seed"] = Opts["seed"].hex()
end

# === INITIALIZE FREETYPE ===
require "./freetype-class.rb"

ft_lib_ptr = FFI::MemoryPointer.new(:pointer)
ft_err = FreeType::C.FT_Init_FreeType(ft_lib_ptr)
raise "FT_Init_FreeType() failed" unless ft_err == 0
ft_lib = ft_lib_ptr.read_pointer()

# === INITIALIZE FREETYPE ===
ft_face_ptr = FFI::MemoryPointer.new(:pointer)
ft_err = FreeType::C.FT_New_Face(ft_lib, Opts.font, 0, ft_face_ptr)
raise "FT_New_Face() failed" unless ft_err == 0
ft_face = FT_FaceRec.new(ft_face_ptr.read_pointer())

# if (ft_face[:face_flags] & FreeType::C::FT_FACE_FLAG_MULTIPLE_MASTERS)
if (ft_face[:face_flags] & (1 << 8))
  puts("this font is multiple master or variable font")
end

# === INITIALIZE WEIGHT ===
ft_mm_var_ptr = FFI::MemoryPointer.new(:pointer)
ft_err = FreeType::C.FT_Get_MM_Var(ft_face, ft_mm_var_ptr)
if (ft_err == 0)
  ft_mm_var = FT_MM_Var.new(ft_mm_var_ptr.read_pointer())
  puts "Number of axis: #{ft_mm_var[:num_axis]}"

  wght = Opts.var_wght
  wdth = Opts.var_wdth

  axis_ptr = ft_mm_var[:axis]
  num_axis = ft_mm_var[:num_axis]
  axis = Array.new(num_axis)
  coord_values = Array.new(num_axis)
  ft_mm_var[:num_axis].times do |axis_idx|
    axis[axis_idx] = FT_Var_Axis.new(axis_ptr + axis_idx * FT_Var_Axis.size)

    str_tag = [ axis[axis_idx][:tag] ].pack("N").encode("us-ascii")
    v_min = axis[axis_idx][:minimum]
    v_def = axis[axis_idx][:def]
    v_max = axis[axis_idx][:maximum]

    is_def = ""
    case (str_tag)
    when "wght" then
      coord_values[axis_idx] = [ [
        v_min,
        v_min + (v_max - v_min) * Opts.var_wght].max,
        v_max
      ].min
    when "wdth" then
      coord_values[axis_idx] = [ [
        v_min,
        v_min + (v_max - v_min) * Opts.var_wdth].max,
        v_max
      ].min
    else
      coord_values[axis_idx] = v_def
      is_def = "(def)"
    end

    printf("axis #%d - tag: %s - range 0x%08x < 0x%08x%s < 0x%08x\n",
      axis_idx, str_tag, v_min, coord_values[axis_idx], is_def, v_max)
  end

  coord_ptr = FFI::MemoryPointer.new(:int32, num_axis)
  coord_ptr.write_array_of_int32(coord_values)

  ft_err = FreeType::C.FT_Set_Var_Design_Coordinates(ft_face, num_axis, coord_ptr)
  raise "FT_Set_Var_Design_Coordinates() failed" unless ft_err == 0

  coord_ptr_r = FFI::MemoryPointer.new(:int32, num_axis)
  ft_err = FreeType::C.FT_Get_Var_Design_Coordinates(ft_face, num_axis, coord_ptr_r)
  raise "FT_Get_Var_Design_Coordinates() failed" unless ft_err == 0
  coord_values_r = coord_ptr_r.read_array_of_int32(num_axis)

  num_axis.times do |axis_idx|
    printf("coord #%d: 0x%08x -> 0x%08x\n",
            axis_idx, coord_values[axis_idx], coord_values_r[axis_idx])
  end
end

# === SET PIXEL SIZE ===
ft_err = FreeType::C.FT_Set_Pixel_Sizes(ft_face, Opts.width, Opts.height)
raise "FT_Set_Pixel_Sizes() failed" unless ft_err == 0

ft_size = FT_SizeRec.new(ft_face[:size])

ft_metric = ft_size[:metrics]

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
glyph_advance_to_baseline  = [0, ft_glyphslot[:bitmap_top]].max
glyph_left_bearing = [0, ft_glyphslot[:bitmap_left]].max

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

# === RANDOM MASK IMAGES ===

def gen_random_mask(img_width, img_height, stroke_color, stroke_width, number_strokes, rand_generator)
  canvas = Magick::Image.new(img_width, img_height) {|options| options.background_color = "none"}
  draw = Magick::Draw.new()
  draw.stroke(stroke_color)
  draw.stroke_width(stroke_width)
  draw.stroke_linecap("round")
  number_strokes.times do
    x = rand_generator.next() % img_width
    y = rand_generator.next() % img_height
    dx = (rand_generator.next() % (img_width / 4))  - (img_width  /8)
    dy = (rand_generator.next() % (img_height / 4)) - (img_height /8)
    draw.line(x, y, x + dx, y + dy)
  end
  draw.draw(canvas)
  return canvas
end

# === SAVE IMAGE ===
img_orig = magick_image # .transparent("white")
img_dist1 = magick_image_distorted1 # .transparent("white")
img_dist2 = magick_image_distorted2 # .transparent("white")

mask_sub1 = gen_random_mask(img_orig.columns, img_orig.rows,
                            "white", img_orig.rows / 20, Opts.noise_subtract,
                            xorshift32)
mask_add1 = gen_random_mask(img_orig.columns, img_orig.rows,
                            "black", img_orig.rows / 20, Opts.noise_add,
                            xorshift32)

mask_sub2 = gen_random_mask(img_orig.columns, img_orig.rows,
                            "white", img_orig.rows / 20, Opts.noise_subtract,
                            xorshift32)
mask_add2 = gen_random_mask(img_orig.columns, img_orig.rows,
                            "black", img_orig.rows / 20, Opts.noise_add,
                            xorshift32)

img_dist1 = img_dist1.composite(mask_sub1, 0, 0, Magick::SrcOverCompositeOp)
                     .composite(mask_add1, 0, 0, Magick::SrcOverCompositeOp)
img_dist2 = img_dist2.composite(mask_sub2, 0, 0, Magick::SrcOverCompositeOp)
                     .composite(mask_add2, 0, 0, Magick::SrcOverCompositeOp)

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
    fi_dist1 = fi_dist1 * 0.8
    fi_dist2 = fi_dist2 * 0.7
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
